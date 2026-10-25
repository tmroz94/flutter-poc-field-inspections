import { expect, test, type Browser, type Page } from '@playwright/test';
import { mkdirSync, writeFileSync } from 'node:fs';

import { enableSemantics, openSignedIn, text } from './flutter';

// JavaScript (CanvasKit) vs WebAssembly (Skwasm) release builds, same code.
const builds = [
  { name: 'JavaScript (CanvasKit)', baseURL: 'http://localhost:5174' },
  { name: 'WebAssembly (Skwasm)', baseURL: 'http://localhost:5176' },
];
const runs = 3;

type Run = {
  firstFrameMs: number;
  scroll: { frames: number; fps: number; p95Ms: number; maxMs: number; over25Pct: number };
  engine: string;
};

const median = (xs: number[]) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];

/** Collects requestAnimationFrame intervals while [action] runs. */
async function pacing(page: Page, action: () => Promise<void>) {
  await page.evaluate(() => {
    const w = window as any;
    w.__deltas = [];
    let last = performance.now();
    w.__run = true;
    const tick = (t: number) => {
      w.__deltas.push(t - last);
      last = t;
      if (w.__run) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });
  await action();
  const d: number[] = await page.evaluate(() => {
    const w = window as any;
    w.__run = false;
    return w.__deltas.slice(2);
  });
  const sorted = [...d].sort((a, b) => a - b);
  const avg = d.reduce((a, b) => a + b, 0) / d.length;
  return {
    frames: d.length,
    fps: Math.round(1000 / avg),
    p95Ms: Math.round(sorted[Math.floor(sorted.length * 0.95)]),
    maxMs: Math.round(sorted[sorted.length - 1]),
    over25Pct: Math.round((d.filter((x) => x > 25).length * 100) / d.length),
  };
}

async function measure(browser: Browser, baseURL: string): Promise<Run> {
  const context = await browser.newContext({ baseURL, viewport: { width: 1280, height: 860 } });
  await context.addInitScript(() => {
    window.addEventListener('flutter-first-frame', () => ((window as any).__firstFrame = performance.now()));
  });
  const page = await context.newPage();

  // Cold load to the first Flutter frame (the sign-in screen).
  await page.goto('/sign-in');
  await page.waitForFunction(() => (window as any).__firstFrame !== undefined, null, { timeout: 60_000 });
  const firstFrameMs = Math.round(await page.evaluate(() => (window as any).__firstFrame));

  await openSignedIn(page, '/inspections');
  await expect(text(page, 'Substation 12').first()).toBeVisible();
  await page.waitForTimeout(1000);

  // Scroll the inspections table down and up with the mouse wheel.
  const scroll = await pacing(page, async () => {
    await page.mouse.move(640, 600);
    for (let i = 0; i < 120; i++) {
      await page.mouse.wheel(0, i < 60 ? 120 : -120);
      await page.waitForTimeout(16);
    }
    await page.waitForTimeout(300);
  });

  // The app's own engine timings (Diagnostics, since start): navigate in-app
  // (history + popstate, which the router follows) so nothing reloads.
  await page.evaluate(() => {
    history.pushState(null, '', '/settings/poc/diagnostics');
    window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
  });
  await enableSemantics(page).catch(() => undefined);
  // Diagnostics rows are merged semantics nodes: one label holds the name and the value.
  await expect(text(page, /build [\d.]+ ms · raster [\d.]+ ms|Not reported/).first()).toBeVisible();
  const all: string = await page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics-host *')].map((e) => e.getAttribute('aria-label') ?? e.textContent ?? '').join(' | '),
  );
  const frames = all.match(/(\d+) · build ([\d.]+) ms · raster ([\d.]+) ms/);
  const slow = all.match(/Over 16 ms\s*([\d.]+)%/);
  const engine = frames ? `${frames[1]} frames, build ${frames[2]} ms, raster ${frames[3]} ms, ${slow?.[1] ?? '?'}% over 16 ms` : 'not reported';

  await context.close();
  return { firstFrameMs, scroll, engine };
}

test('JS vs WebAssembly: first frame and scroll smoothness', async ({ browser }) => {
  const results: Record<string, Run[]> = {};
  for (const b of builds) {
    results[b.name] = [];
    for (let i = 0; i < runs; i++) results[b.name].push(await measure(browser, b.baseURL));
  }
  const summary = Object.entries(results).map(([name, rs]) => ({
    build: name,
    firstFrameMs: median(rs.map((r) => r.firstFrameMs)),
    scrollFps: median(rs.map((r) => r.scroll.fps)),
    scrollP95Ms: median(rs.map((r) => r.scroll.p95Ms)),
    scrollOver25Pct: median(rs.map((r) => r.scroll.over25Pct)),
    engine: rs.map((r) => r.engine),
  }));
  console.table(summary.map(({ engine, ...rest }) => rest));
  for (const s of summary) console.log(`${s.build} engine timings: ${s.engine.join(' | ')}`);
  mkdirSync('test-results', { recursive: true });
  writeFileSync('test-results/perf.json', JSON.stringify({ when: new Date().toISOString(), runs, results, summary }, null, 2));
  for (const s of summary) expect(s.scrollFps).toBeGreaterThan(0);
});
