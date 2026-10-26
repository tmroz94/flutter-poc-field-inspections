import { expect, type Locator, type Page } from '@playwright/test';

/**
 * Flutter web draws to a canvas; its accessibility tree (flt-semantics) is
 * what Playwright can find and click. It is built once a user asks for it,
 * through the hidden "Enable accessibility" placeholder.
 */
export async function enableSemantics(page: Page): Promise<void> {
  await page.waitForFunction(() => document.querySelector('flt-semantics-placeholder') || document.querySelector('flt-semantics'));
  await page.evaluate(() => (document.querySelector('flt-semantics-placeholder') as HTMLElement | null)?.click());
  await page.waitForFunction(() => document.querySelectorAll('flt-semantics').length > 5);
}

/** Opens [path]; signs in with the demo account when the guard asks for it. */
export async function openSignedIn(page: Page, path: string): Promise<void> {
  await page.goto(path);
  await enableSemantics(page);
  const demo = page.getByRole('button', { name: 'Use demo account' });
  const target = new RegExp(escape(path.split('?')[0]));
  // isVisible() doesn't wait (its timeout is ignored); give the guard's
  // redirect to sign-in a moment to show the button.
  let signInShown = true;
  try {
    await demo.waitFor({ state: 'visible', timeout: 5_000 });
  } catch {
    signInShown = false;
  }
  if (signInShown) await demo.click();
  await expect(page).toHaveURL(target);
  await enableSemantics(page).catch(() => undefined);
}

/** Scrolls the page's Flutter view with the mouse wheel until [target] shows. */
export async function scrollTo(page: Page, target: Locator, at = { x: 640, y: 500 }): Promise<void> {
  for (let i = 0; i < 40 && !(await target.isVisible().catch(() => false)); i++) {
    await page.mouse.move(at.x, at.y);
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(150);
  }
  await expect(target).toBeVisible();
}

export function escape(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Text in the Flutter semantics tree (not its aria-live announcements, which
 * repeat snackbars). Merged widgets such as list tiles carry their text as an
 * aria-label instead of text content, so both are searched.
 */
export function text(page: Page, matcher: string | RegExp): Locator {
  const host = page.locator('flt-semantics-host');
  return host.getByText(matcher).or(host.getByLabel(matcher));
}
