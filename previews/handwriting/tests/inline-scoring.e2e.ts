import { test } from "@e2e-dev/web"
import { expect } from "e2e"

type Fixtures = Parameters<Parameters<typeof test>[1]>[0]

async function settle(browser: Fixtures["browser"]) {
  await expect.poll(() => browser.evaluate(() => document.getAnimations().every(animation => animation.playState !== "running"))).toBe(true)
}

async function draw(browser: Fixtures["browser"], paths: number[][][]) {
  await settle(browser)
  const transform = await browser.evaluate(() => {
    const svg = document.querySelector<SVGSVGElement>('[data-testid="score-canvas"]')!
    const matrix = svg.getScreenCTM()!
    return { a: matrix.a, d: matrix.d, e: matrix.e, f: matrix.f }
  })
  for (const path of paths) {
    const [start, ...rest] = path
    await browser.mouse.move(transform.e + start[0] * transform.a, transform.f + start[1] * transform.d)
    await browser.mouse.down()
    for (const point of rest) await browser.mouse.move(transform.e + point[0] * transform.a, transform.f + point[1] * transform.d)
    await browser.mouse.up()
  }
}

const twentyFour = [
  [[180, 310], [185, 280], [200, 250], [225, 228], [260, 216], [300, 218], [332, 230], [351, 250], [360, 280], [356, 308], [340, 338], [315, 365], [280, 396], [242, 430], [205, 470], [177, 516], [168, 540], [220, 540], [275, 540], [330, 540], [370, 540]],
  [[650, 220], [620, 265], [590, 310], [560, 355], [530, 400], [510, 440], [555, 440], [600, 440], [650, 440], [705, 440]],
  [[670, 230], [670, 280], [670, 335], [670, 390], [670, 445], [670, 500], [670, 550], [670, 600]],
]

test("one tap saves, advances, supports Undo and replaces an edited round score", async ({ app, screen, browser }) => {
  await app.open("/?state=write&preset=softer")
  await expect(screen.getByRole("dialog", "Leo")).toBeVisible()
  await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "0")
  await expect(screen.getByRole("button", "Save score")).toBeDisabled()
  await screen.getByRole("button", "Type score", { exact: true }).tap()
  await screen.getByRole("textbox", "Score for this round").fill("24")
  await expect(screen.getByTestId("recognition-status")).toContainText("Leo’s total to 33")
  await screen.getByRole("button", "Save score").tap()
  await expect(screen.getByRole("dialog", "Maya")).toBeVisible()
  await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "0")
  await expect(screen.getByRole("button", "Save score")).toBeDisabled()
  await expect(screen.getByTestId("score-toast")).toContainText("Leo’s total is now 33")
  await settle(browser)
  await app.screenshot("saved-and-next-player")
  await screen.getByRole("button", "Undo", { exact: true }).tap()
  await expect(screen.getByRole("dialog", "Leo")).toBeVisible()
  await expect(screen.getByRole("textbox", "Score for this round")).toHaveValue("24")
  await expect(screen.getByTestId("score-toast")).toContainText("Leo’s total is back to 9")
  await screen.getByRole("button", "Save score").tap()
  await expect(screen.getByRole("dialog", "Maya")).toBeVisible()
  await screen.getByRole("button", "Type score", { exact: true }).tap()
  await screen.getByRole("textbox", "Score for this round").fill("7")
  await screen.getByRole("button", "Save score").tap()
  await expect(screen.getByRole("dialog")).not.toBeVisible()
  await expect(screen.getByTestId("player-leo")).toContainText("33")
  await expect(screen.getByTestId("player-maya")).toContainText("14")
  await screen.getByTestId("player-leo").tap()
  await screen.getByRole("textbox", "Score for this round").fill("25")
  await expect(screen.getByTestId("recognition-status")).toContainText("Leo’s total to 34")
  await screen.getByRole("button", "Save score").tap()
  await expect(screen.getByTestId("player-leo")).toContainText("34")
  await expect(screen.getByTestId("score-toast")).toContainText("Leo’s total is now 34")
  await screen.getByRole("button", "Undo", { exact: true }).tap()
  await expect(screen.getByTestId("score-toast")).toContainText("Leo’s total is back to 33")
})

test("player drafts survive switching, reload and rotation", async ({ app, screen, browser }) => {
  await app.open("/?state=write")
  await screen.getByRole("button", "Type score", { exact: true }).tap()
  await screen.getByRole("textbox", "Score for this round").fill("42")
  await screen.getByRole("button", "Close score entry").tap()
  await screen.getByTestId("player-maya").tap()
  await screen.getByRole("button", "Type score", { exact: true }).tap()
  await screen.getByRole("textbox", "Score for this round").fill("7")
  await screen.getByRole("button", "Close score entry").tap()
  await screen.getByTestId("player-leo").tap()
  await expect(screen.getByRole("textbox", "Score for this round")).toHaveValue("42")
  await browser.reload()
  await expect(screen.getByRole("dialog", "Leo")).toBeVisible()
  await expect(screen.getByRole("textbox", "Score for this round")).toHaveValue("42")
  await browser.setViewport({ width: 874, height: 402 })
  await expect(screen.getByRole("textbox", "Score for this round")).toHaveValue("42")
  await expect.poll(async () => {
    const controls = await browser.evaluate(() => Array.from(document.querySelectorAll<HTMLElement>(".entry-action-row button")).map(element => {
    const box = element.getBoundingClientRect()
    return { width: box.width, height: box.height, bottom: box.bottom, viewport: innerHeight }
  }))
    return controls.every(control => control.width >= 44 && control.height >= 44 && control.bottom <= control.viewport)
  }).toBe(true)
  await settle(browser)
  await app.screenshot("landscape-score-entry")
  await browser.setViewport({ width: 402, height: 874 })
  await screen.getByRole("button", "Close score entry").tap()
  await screen.getByTestId("player-maya").tap()
  await expect(screen.getByRole("textbox", "Score for this round")).toHaveValue("7")
  await browser.emulateMedia({ reducedMotion: "reduce" })
  const duration = await browser.evaluate(() => getComputedStyle(document.querySelector('[data-testid="score-dialog"]')!).animationDuration)
  expect(duration).toBe("0s")
})

test("real drawn ink is recognised locally and saved without another screen", { timeout: 90000 }, async ({ app, screen, browser }) => {
  await app.open("/?state=write&preset=softer")
  await draw(browser, twentyFour)
  await expect(screen.getByTestId("recognition-status")).toContainText("A score of 24", { timeout: 35000 })
  await expect(screen.getByTestId("recognition-status")).toContainText("Leo’s total to 33")
  await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "3")
  await settle(browser)
  await app.screenshot("real-handwriting-recognised")
  await screen.getByRole("button", "Save score").tap()
  await expect(screen.getByRole("dialog", "Maya")).toBeVisible()
  await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "0")
  await expect(screen.getByTestId("score-toast")).toContainText("Leo’s total is now 33")
})

test("uncertain readings stay inline and keyboard correction can save zero", async ({ app, screen, browser }) => {
  await browser.route("**/api/recognise", route => route.fulfill({ status: 200, json: { status: "unreadable" } }))
  await app.open("/?state=write")
  await draw(browser, [[[200, 300], [400, 400], [200, 500], [500, 600]]])
  await expect(screen.getByTestId("recognition-status")).toContainText("Please write the score again")
  await expect(screen.getByRole("button", "Save score")).toBeDisabled()
  await screen.getByRole("button", "Type score", { exact: true }).tap()
  await screen.getByRole("textbox", "Score for this round").fill("0")
  await expect(screen.getByTestId("recognition-status")).toContainText("A score of 0")
  await screen.getByRole("button", "Save score").tap()
  await expect(screen.getByRole("dialog", "Maya")).toBeVisible()
  await expect(screen.getByTestId("score-toast")).toContainText("Leo’s total is now 9")
})

test("clearing ink disables saving and separate ink drafts persist", async ({ app, screen, browser }) => {
  await app.open("/?state=write")
  await draw(browser, twentyFour)
  await expect(screen.getByTestId("recognition-status")).toContainText("A score of 24", { timeout: 35000 })
  await screen.getByRole("button", "Close score entry").tap()
  await screen.getByTestId("player-maya").tap()
  await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "0")
  await screen.getByRole("button", "Close score entry").tap()
  await screen.getByTestId("player-leo").tap()
  await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "3")
  await browser.reload()
  await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "3")
  await expect(screen.getByTestId("recognition-status")).toContainText("A score of 24", { timeout: 35000 })
  await screen.getByRole("button", "Clear score", { exact: true }).tap()
  await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "0")
  await expect(screen.getByRole("button", "Save score")).toBeDisabled()
  await expect(screen.getByTestId("recognition-status")).toContainText("Write a score")
})
test("a new handwriting entry can be corrected inline while replacing an earlier score", { timeout: 90000 }, async ({ app, screen, browser }) => {
  await app.open("/?state=write")
  await draw(browser, twentyFour)
  await expect(screen.getByTestId("recognition-status")).toContainText("A score of 24", { timeout: 35000 })
  await browser.setViewport({ width: 874, height: 402 })
  await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "3")
  await expect(screen.getByTestId("recognition-status")).toContainText("A score of 24")
  await settle(browser)
  await app.screenshot("landscape-handwriting")
  await browser.setViewport({ width: 402, height: 874 })
  await screen.getByRole("button", "Save score").tap()
  await expect(screen.getByRole("dialog", "Maya")).toBeVisible()
  await screen.getByRole("button", "Type score", { exact: true }).tap()
  await screen.getByRole("textbox", "Score for this round").fill("7")
  await screen.getByRole("button", "Save score").tap()
  await expect(screen.getByRole("dialog")).not.toBeVisible()
  await screen.getByTestId("player-leo").tap()
  await screen.getByRole("button", "Clear score", { exact: true }).tap()
  await draw(browser, [
    [[190, 300], [230, 260], [280, 220], [280, 290], [280, 360], [280, 440], [280, 520], [280, 600]],
    [[490, 220], [540, 220], [590, 220], [645, 220], [700, 220], [670, 275], [640, 330], [610, 390], [580, 450], [550, 515], [520, 590]],
  ])
  await expect.poll(() => browser.evaluate(() => document.querySelector<HTMLElement>('[data-testid="recognition-status"]')!.dataset.readingState), { timeout: 35000 }).toMatch(/^(ready|unreadable)$/)
  const reading = await browser.evaluate(() => document.querySelector<HTMLElement>('[data-testid="recognition-status"]')!.dataset.readingState!)
  if (reading === "unreadable") {
    await expect(screen.getByRole("button", "Save score")).toBeDisabled()
    await app.screenshot("uncertain-handwriting-stays-inline")
    await screen.getByRole("button", "Type score", { exact: true }).tap()
    await screen.getByRole("textbox", "Score for this round").fill("17")
  }
  await expect(screen.getByTestId("recognition-status")).toContainText("A score of 17")
  await expect(screen.getByTestId("recognition-status")).toContainText("Leo’s total to 26")
  await settle(browser)
  await app.screenshot("new-handwriting-replaces-round-score")
  await screen.getByRole("button", "Save score").tap()
  await expect(screen.getByTestId("player-leo")).toContainText("26")
  await expect(screen.getByTestId("score-toast")).toContainText("Leo’s total is now 26")
})
test("a second handwritten number is recognised as 42", async ({ app, screen, browser }) => {
  await app.open("/?state=write")
  const fortyTwo = [
    twentyFour[1].map(([x, y]) => [x - 340, y]),
    twentyFour[2].map(([x, y]) => [x - 340, y]),
    twentyFour[0].map(([x, y]) => [x + 340, y]),
  ]
  await draw(browser, fortyTwo)
  await expect(screen.getByTestId("recognition-status")).toContainText("A score of 42", { timeout: 35000 })
  await expect(screen.getByTestId("recognition-status")).toContainText("Leo’s total to 51")
  await settle(browser)
  await app.screenshot("different-handwriting-recognised")
  await screen.getByRole("button", "Save score").tap()
  await expect(screen.getByTestId("score-toast")).toContainText("Leo’s total is now 51")
})
