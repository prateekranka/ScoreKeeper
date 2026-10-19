import { test } from "@e2e-dev/web"
import { expect } from "e2e"
import { randomUUID } from "node:crypto"

test("the private handwriting link opens without adding test drawings to the collection", async ({ app, screen, browser }) => {
  const writer = randomUUID()
  const before = await (await fetch(`${app.baseUrl}/api/handwriting/session?writer=${writer}`)).json()
  expect(before.writerSaved).toBe(0)
  await app.open("/handwriting")
  await expect(screen.getByRole("heading", "Show us how you write")).toBeVisible()
  await expect(screen.getByRole("status")).toContainText("Check that your drawing")
  await expect(screen.getByTestId("sample-expected")).toHaveText("0")
  await expect(screen.getByRole("button", "Save sample", { exact: true })).toBeDisabled()
  await expect(screen.getByRole("button", "New writer", { exact: true })).toBeVisible()
  await app.screenshot("private-handwriting-collection-portrait")
  await browser.setViewport({ width: 874, height: 402 })
  await browser.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" })
  expect(await browser.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  expect(await browser.evaluate(() => [...document.querySelectorAll('.sample-action-row button')].every(element => { const rect = element.getBoundingClientRect(); return rect.width >= 44 && rect.height >= 44 }))).toBe(true)
  await app.screenshot("private-handwriting-collection-landscape")
  await browser.setViewport({ width: 320, height: 568 })
  expect(await browser.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  const after = await (await fetch(`${app.baseUrl}/api/handwriting/session?writer=${writer}`)).json()
  expect(after.writerSaved).toBe(0)
})

test("the Jev page gives a direct route to contribute handwriting", async ({ app, screen }) => {
  await app.open("/setup/jev")
  await screen.getByRole("link", "Add handwriting samples", { exact: true }).tap()
  await expect(screen.getByRole("heading", "Show us how you write")).toBeVisible()
  await expect(screen.getByRole("status")).toContainText("Check that your drawing")
})
