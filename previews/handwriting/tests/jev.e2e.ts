import { beforeEach, test } from "@e2e-dev/web"
import { expect } from "e2e"
import { readFile } from "node:fs/promises"

type Fixtures = Parameters<Parameters<typeof test>[1]>[0]
const dummy = "e2e-dummy-key-not-a-credential"

async function reset(base: string | undefined, value: Record<string, unknown> = {}) {
  const response = await fetch(`${base}/api/test/jev`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(value) })
  expect(response.status).toBe(200)
}
async function sample() {
  const fixtures = JSON.parse(await readFile(`${process.env.PIPCOUNT_DIGIT_EVIDENCE}/user-fixtures.json`, "utf8")) as { file: string; expected: number }[]
  return readFile(fixtures.find(row => row.expected === 4)!.file)
}
async function recognise(base: string | undefined) {
  const response = await fetch(`${base}/api/recognise`, { method: "POST", headers: { "Content-Type": "image/png" }, body: await sample() })
  expect(response.status).toBe(200)
  return response.json()
}
async function drawFour(browser: Fixtures["browser"]) {
  await expect.poll(() => browser.evaluate(() => document.getAnimations().every(a => a.playState !== "running"))).toBe(true)
  const m = await browser.evaluate(() => {
    const matrix = document.querySelector<SVGSVGElement>('[data-testid="score-canvas"]')!.getScreenCTM()!
    return { a: matrix.a, d: matrix.d, e: matrix.e, f: matrix.f }
  })
  for (const [start, ...rest] of [[[560,200],[300,500],[650,500]],[[560,200],[560,710]]]) {
    await browser.mouse.move(m.e + start[0] * m.a, m.f + start[1] * m.d)
    await browser.mouse.down()
    for (const point of rest) await browser.mouse.move(m.e + point[0] * m.a, m.f + point[1] * m.d)
    await browser.mouse.up()
  }
}

beforeEach(async ({ app }) => reset(app.baseUrl))

test("private key entry requests engineering advice and waits for evaluation", async ({ app, screen, browser }) => {
  await app.open("/setup/jev")
  const input = screen.getByLabel("TypeSafe API key")
  await expect(input).toBeVisible()
  await expect(screen.getByRole("button", "Connect Jev", { exact: true })).toBeDisabled()
  await input.fill(dummy)
  await screen.getByRole("button", "Connect Jev", { exact: true }).tap()
  await expect(screen.getByRole("status")).toContainText("connected and ready for evaluation")
  await expect(screen.getByRole("button", "Replace key", { exact: true })).toBeDisabled()
  await expect(screen.getByTestId("jev-recommendation")).toContainText("independent check")
  expect(await browser.evaluate(() => ({ local: { ...localStorage }, session: { ...sessionStorage } }))).toEqual({ local: {}, session: {} })
  const statusText = await (await fetch(`${app.baseUrl}/api/jev/status`)).text()
  expect(statusText.includes(dummy)).toBe(false)
  const status = JSON.parse(statusText)
  expect(status.configured).toBe(true)
  expect(status.mode).toBe("awaiting_evaluation")
  expect((await recognise(app.baseUrl)).value).toBe(4)
  const state = await (await fetch(`${app.baseUrl}/api/test/jev`)).json()
  expect(state.calls.map((row: { kind: string }) => row.kind)).toEqual(["engineering"])
  await app.screenshot("jev-connected-awaiting-evaluation")
})

test("key entry rejects other origins and missing or wrong CSRF tokens", async ({ app }) => {
  const status = await (await fetch(`${app.baseUrl}/api/jev/status`)).json()
  for (const headers of [
    { Origin: "https://unrelated.invalid", "X-Pipcount-CSRF": status.csrfToken },
    { Origin: app.baseUrl!, "X-Pipcount-CSRF": "wrong" },
    { Origin: app.baseUrl! },
    { "X-Pipcount-CSRF": status.csrfToken },
  ]) {
    const response = await fetch(`${app.baseUrl}/api/jev/connect`, { method: "POST", headers: { "Content-Type": "application/json", ...headers }, body: JSON.stringify({ apiKey: dummy }) })
    expect(response.status).toBe(403)
    expect((await response.text()).includes(dummy)).toBe(false)
  }
  const state = await (await fetch(`${app.baseUrl}/api/test/jev`)).json()
  expect(state.calls).toEqual([])
  expect(state.status.configured).toBe(false)
})

for (const [failure, message] of [["unauthorized", "could not accept that key"], ["keychain", "unlock the login Keychain"], ["timeout", "could not connect"]]) {
  test(`private connection handles ${failure} without retaining the typed key`, async ({ app, screen }) => {
    await reset(app.baseUrl, { case: failure })
    await app.open("/setup/jev")
    const input = screen.getByLabel("TypeSafe API key")
    await input.fill(dummy)
    await screen.getByRole("button", "Connect Jev", { exact: true }).tap()
    await expect(screen.getByRole("status")).toContainText(message)
    await expect(screen.getByRole("button", "Connect Jev", { exact: true })).toBeDisabled()
    const state = await (await fetch(`${app.baseUrl}/api/test/jev`)).json()
    expect(state.status.configured).toBe(false)
    expect(state.status.mode).toBe("local")
  })
}

test("independent agreement keeps the one-tap save, advance and Undo flow", async ({ app, screen, browser }) => {
  await reset(app.baseUrl, { configured: true, active: true })
  await app.open("/?state=write&preset=softer")
  await drawFour(browser)
  await expect(screen.getByTestId("recognition-status")).toContainText("A score of 4 will bring Leo’s total to 13")
  await screen.getByRole("button", "Save score").tap()
  await expect(screen.getByRole("dialog", "Maya")).toBeVisible()
  await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "0")
  await expect(screen.getByTestId("score-toast")).toContainText("Leo’s total is now 13")
  await screen.getByRole("button", "Undo", { exact: true }).tap()
  await expect(screen.getByRole("dialog", "Leo")).toBeVisible()
  await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "2")
  const state = await (await fetch(`${app.baseUrl}/api/test/jev`)).json()
  expect(state.calls.some((row: { kind: string; stateKeys: string[] }) => row.kind === "drawing" && JSON.stringify(row.stateKeys) === '["drawing"]')).toBe(true)
  await app.screenshot("jev-contract-agreement-undo")
})

test("disagreement preserves the drawing and keyboard entry remains available", async ({ app, screen, browser }) => {
  await reset(app.baseUrl, { configured: true, active: true, case: "disagree" })
  await app.open("/?state=write&preset=softer")
  await drawFour(browser)
  await expect(screen.getByTestId("recognition-status")).toContainText("Please write the score again")
  await expect(screen.getByRole("button", "Save score")).toBeDisabled()
  await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "2")
  await screen.getByRole("button", "Type score", { exact: true }).tap()
  await screen.getByRole("textbox", "Score for this round").fill("4")
  await screen.getByRole("button", "Save score").tap()
  await expect(screen.getByRole("dialog", "Maya")).toBeVisible()
  await expect(screen.getByTestId("score-toast")).toContainText("Leo’s total is now 13")
})

for (const [failure, expected] of [["unreadable", "unreadable"], ["lowconfidence", "unreadable"], ["timeout", "error"], ["unauthorized", "error"], ["badmodel", "error"], ["badprobabilities", "error"], ["badmass", "error"], ["excessmass", "error"], ["notrounded", "error"]]) {
  test(`active checking rejects ${failure} without a silent local fallback`, async ({ app }) => {
    await reset(app.baseUrl, { configured: true, active: true, case: failure })
    expect((await recognise(app.baseUrl)).status).toBe(expected)
  })
}

test("rounded provider probabilities retain the original acceptance thresholds", async ({ app }) => {
  await reset(app.baseUrl, { configured: true, active: true, case: "rounded" })
  const result = await recognise(app.baseUrl)
  expect(result.status).toBe("ready")
  expect(result.value).toBe(4)
})

test("a tiny evaluation cannot activate Jev even when its single reading is correct", async ({ app }) => {
  await reset(app.baseUrl, { configured: true, active: true })
  const response = await fetch(`${app.baseUrl}/api/test/evaluate`, { method: "POST" })
  const report = await response.json()
  expect(response.status).toBe(200)
  expect(report.combined.wrongAccepted).toBe(0)
  expect(report.eligible).toBe(false)
  expect(report.checks.independentHoldoutCount).toBe(false)
  expect(report.checks.independentWriterCount).toBe(false)
  expect(report.mode).toBe("awaiting_evaluation")
})

test("the connection page remains usable in landscape, dark mode and reduced motion", async ({ app, screen, browser }) => {
  await app.open("/setup/jev")
  await browser.setViewport({ width: 874, height: 402 })
  await browser.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" })
  await screen.getByLabel("TypeSafe API key").fill(dummy)
  await screen.getByRole("button", "Connect Jev", { exact: true }).tap()
  await expect(screen.getByRole("status")).toContainText("connected and ready for evaluation")
  expect(await browser.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  expect(await browser.evaluate(() => Array.from(document.querySelectorAll('input,button')).every(element => element.getBoundingClientRect().height >= 44))).toBe(true)
  await app.screenshot("jev-setup-landscape-dark")
})
