import { expect, test, type BrowserContext, type Page } from '@playwright/test';
import { writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { enableSemantics, openSignedIn, scrollTo, text } from './flutter';

const route = '/map?site=s-riverside-office'; // the "Map" row of the deep-link tester

/** Notifications the page's service workers are showing. */
async function shown(page: Page): Promise<{ title: string; body: string }[]> {
  return page.evaluate(async () => {
    const regs = await navigator.serviceWorker.getRegistrations();
    const all = await Promise.all(regs.map((r) => r.getNotifications()));
    return all.flat().map((n) => ({ title: n.title, body: n.body }));
  });
}

/**
 * Clicks the first shown notification the way the browser would: the
 * plugin's service worker runs its notificationclick handler.
 */
async function clickNotification(context: BrowserContext): Promise<void> {
  const sw = context.serviceWorkers().find((w) => w.url().includes('notifications_service_worker'));
  expect(sw, 'the notifications service worker is running').toBeTruthy();
  await sw!.evaluate(async () => {
    const [n] = await (self as any).registration.getNotifications();
    await (self as any)._handleNotif({ notification: n, action: '', reply: null, waitUntil: () => undefined });
  });
}

async function sendTestNotification(page: Page): Promise<void> {
  const bell = page.getByRole('button', { name: 'Notification for Map' });
  await scrollTo(page, bell);
  await bell.click();
  await expect(text(page, /Notification in 5 s/)).toBeVisible();
  await expect.poll(() => shown(page), { timeout: 20_000 }).toContainEqual({ title: 'Test link', body: route });
}

test.describe('notifications', () => {
  test.use({ permissions: ['notifications'] });

  test('a test notification is shown, and clicking it opens its route', async ({ page, context }) => {
    await openSignedIn(page, '/settings/poc/deep-links');
    await sendTestNotification(page);
    await clickNotification(context);
    await expect(page).toHaveURL(/\/map\?site=s-riverside-office/);
  });

  // With no tab open, the plugin's service worker opens
  // /?notification_payload=<route>. Chrome only lets a worker open windows in
  // response to a real click, so the test opens that same URL itself.
  test('with the tab closed, the URL the worker opens leads to the route', async ({ page, context }) => {
    await openSignedIn(page, '/settings/poc/deep-links');
    await sendTestNotification(page);
    const sw = context.serviceWorkers().find((w) => w.url().includes('notifications_service_worker'));
    const url: string = await sw!.evaluate(async () => {
      const [n] = await (self as any).registration.getNotifications();
      return `/?notification_id=${encodeURIComponent(n.tag)}&notification_payload=${encodeURIComponent(n.data?.payload || '')}&notification_action=&notification_reply=`;
    });
    await page.close();
    const tab = await context.newPage();
    await tab.goto(url);
    await expect(tab).toHaveURL(/\/map\?site=s-riverside-office/, { timeout: 20_000 });
  });
});

test.describe('location', () => {
  test.use({ permissions: ['geolocation'], geolocation: { latitude: 52.2401, longitude: 21.0301 } });

  test('position next to the site, then 7 km away with the warning', async ({ page, context }) => {
    await openSignedIn(page, '/inspections/new?step=1');
    // Real key presses: Flutter's text input listens to them, not to fill().
    await page.getByRole('textbox', { name: 'Site' }).click();
    await page.keyboard.type('River', { delay: 50 });
    await page.getByRole('button', { name: /Riverside office, floor 4/ }).first().click();
    await page.getByRole('button', { name: 'Check location' }).click();
    await expect(text(page, /\d+ m from the site/)).toBeVisible();
    await expect(text(page, /more than 200 m/)).toHaveCount(0);

    await context.setGeolocation({ latitude: 52.3, longitude: 21.03 });
    await page.getByRole('button', { name: 'Update location' }).click();
    await expect(text(page, 'You seem to be more than 200 m from the site address.')).toBeVisible();
  });
});

test.describe('location denied', () => {
  test('a denied permission explains the check is optional', async ({ page, context, baseURL }) => {
    // Deny geolocation for the site the way a user's "Block" would.
    const cdp = await context.newCDPSession(page);
    await cdp.send('Browser.setPermission', { permission: { name: 'geolocation' }, setting: 'denied', origin: baseURL! });
    await openSignedIn(page, '/inspections/new?step=1');
    await page.getByRole('button', { name: 'Check location' }).click();
    // Browsers don't distinguish "denied once" from "blocked": either message explains it.
    await expect(text(page, /Location permission was not given|Location is blocked for this app/).first()).toBeVisible();
  });
});

test.describe('camera and files', () => {
  test('"Use camera" opens the browser file input; the picked photo lands in the grid', async ({ page }) => {
    const photo = join(tmpdir(), 'fi_web_photo.png');
    // 1×1 PNG.
    writeFileSync(photo, Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', 'base64'));
    // INS-1031 has no checklist answers yet, so the step guard stops at step 3:
    // answer all 18 with Pass, then go on to the photos step.
    await openSignedIn(page, '/inspections/INS-1031/edit?step=3');
    const done = text(page, /18 of 18 answered/);
    for (let i = 0; i < 40 && !(await done.isVisible().catch(() => false)); i++) {
      const passes = page.getByRole('button', { name: 'Pass', exact: true });
      for (let j = 0; j < (await passes.count()); j++) await passes.nth(j).click().catch(() => undefined);
      await page.mouse.move(640, 500);
      await page.mouse.wheel(0, 400);
      await page.waitForTimeout(200);
    }
    await expect(done.first()).toBeVisible();
    await page.getByRole('button', { name: /^Next/ }).first().click();
    await expect(page).toHaveURL(/step=4/);
    await enableSemantics(page).catch(() => undefined);
    const counter = text(page, /^Photos · \d+$/);
    const before = Number((await counter.textContent())!.match(/\d+/)![0]);
    const chooser = page.waitForEvent('filechooser');
    await page.getByRole('button', { name: 'Use camera' }).click();
    const picker = await chooser;
    expect(picker.isMultiple()).toBe(false);
    await picker.setFiles(photo);
    await expect(counter).toHaveText(`Photos · ${before + 1}`);
  });
});
