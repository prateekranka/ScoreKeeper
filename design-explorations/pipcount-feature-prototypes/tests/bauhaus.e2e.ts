import { test } from '@e2e-dev/web';
import { expect } from 'e2e';

test('four feature layouts retain the native Bauhaus identity', async ({ app, browser, screen }) => {
  await app.open('/?view=compare&mode=production');
  for (const key of ['A', 'B', 'C', 'D']) {
    const phone = screen.getByTestId('prototype-' + key);
    for (const label of ['Home', 'Games', 'Players', 'More']) {
      await expect(phone.getByRole('button', label)).toBeVisible();
    }
  }
  const identity = await browser.evaluate(() => [...document.querySelectorAll('.phone')].map(phone => {
    const brand = phone.querySelector('.brand')!;
    const button = phone.querySelector('.primary')!;
    const dock = phone.querySelector('.app-nav')!;
    const styles = getComputedStyle(phone);
    return {
      paper: styles.getPropertyValue('--paper').trim(),
      ink: styles.getPropertyValue('--ink').trim(),
      blue: styles.getPropertyValue('--accent').trim(),
      brandSize: getComputedStyle(brand).fontSize,
      brandWeight: getComputedStyle(brand).fontWeight,
      starRays: brand.querySelectorAll('.brand-star rect').length,
      buttonRadius: getComputedStyle(button).borderRadius,
      buttonVisibleAboveDock: button.getBoundingClientRect().bottom < dock.getBoundingClientRect().top,
      art: phone.querySelector('.bauhaus-art')!.className,
    };
  }));
  expect(identity).toHaveLength(4);
  for (const item of identity) {
    expect(item.paper).toBe('#F6F2E8');
    expect(item.ink).toBe('#0B0B0B');
    expect(item.blue).toBe('#0D47D9');
    expect(item.brandSize).toBe('34px');
    expect(item.brandWeight).toBe('900');
    expect(item.starRays).toBe(8);
    expect(item.buttonRadius).toBe('18px');
    expect(item.buttonVisibleAboveDock).toBe(true);
  }
  await app.screenshot('four-bauhaus-feature-layouts');
});

test('score entry and round correction work at phone width', async ({ app, browser, screen }) => {
  await browser.setViewport({ width: 390, height: 844 });
  await app.open('/?variant=C&mode=production');
  await expect(screen.getByTestId('total-mina')).toHaveText('50');
  await screen.getByRole('button', 'enter round 4').tap();
  await screen.getByLabel('Score for Mina').fill('150');
  await screen.getByLabel('Score for Omar').fill('-5');
  await screen.getByLabel('Score for Jules').fill('12');
  await screen.getByLabel('Score for Sam').fill('0');
  await screen.getByRole('button', 'Save round').tap();
  await expect(screen.getByTestId('total-mina')).toHaveText('200');
  await expect(screen.getByTestId('total-omar')).toHaveText('65');
  await screen.getByRole('button', 'Edit round 1, Mina: 18').tap();
  await screen.getByLabel('Score for Mina').fill('20');
  await screen.getByRole('button', 'Save correction').tap();
  await expect(screen.getByTestId('total-mina')).toHaveText('202');
  await expect(screen.getByRole('button', 'enter round 5')).toBeVisible();
  const dimensions = await browser.evaluate(() => ({
    viewport: innerWidth,
    document: document.documentElement.scrollWidth,
    phone: document.querySelector('.phone')!.getBoundingClientRect().width,
  }));
  expect(dimensions.document).toBe(dimensions.viewport);
  expect(dimensions.phone).toBeLessThanOrEqual(390);
  await app.screenshot('phone-score-ledger-after-correction');
  await app.open('/?variant=A&mode=production');
  await app.screenshot('phone-native-home');
});

test('saved crew and recap remain reachable through the native dock', async ({ app, browser, screen }) => {
  await browser.setViewport({ width: 390, height: 844 });
  await app.open('/?variant=B&mode=production');
  await screen.getByRole('button', 'next game, same crew').tap();
  await expect(screen.getByRole('dialog', 'Saved game presets')).toBeVisible();
  await screen.getByRole('button', 'Start next game').tap();
  await expect(screen.getByText('Friday regulars', { exact: true })).toBeVisible();
  await screen.getByRole('button', 'Players').tap();
  await expect(screen.getByRole('heading', 'Your people.')).toBeVisible();
  await screen.getByRole('button', 'Games').tap();
  await expect(screen.getByRole('heading', 'your games')).toBeVisible();
  await screen.getByRole('button', 'More').tap();
  await screen.getByRole('button', /game night recap/).tap();
  await expect(screen.getByRole('region', 'Game Night summary')).toBeVisible();
  await expect(screen.getByText('3 games finished', { exact: false })).toBeVisible();
  await app.screenshot('phone-night-recap');
});

test('night story handles a fresh crew without a record', async ({ app, browser, screen }) => {
  await browser.setViewport({ width: 390, height: 844 });
  await app.open('/?variant=D&mode=production');
  await screen.getByRole('button', 'Players').tap();
  await screen.getByRole('button', /Sunday family/).tap();
  await screen.getByRole('button', /Friday Rummy/).tap();
  await screen.getByRole('button', 'Start night').tap();
  await expect(screen.getByRole('region', 'Game Night summary')).toBeVisible();
  await expect(screen.getByText('Sunday family · wins, not mixed points', { exact: true })).toBeVisible();
  await expect(screen.getByText('personal best', { exact: true })).toHaveCount(0);
});
