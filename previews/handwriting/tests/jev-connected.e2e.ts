import { test } from "@e2e-dev/web"
import { expect } from "e2e"

if (process.env.PIPCOUNT_JEV_CONNECTED === "1") {
  test("the connected preview shows the measured results and leaves cloud acceptance inactive", async ({ app, screen }) => {
    const response = await fetch(`${app.baseUrl}/api/jev/status`)
    const status = await response.json()
    expect(response.status).toBe(200)
    expect(status.configured).toBe(true)
    expect(status.mode).toBe("awaiting_evaluation")
    expect(status.engineering.choice).toBe("collect_writers")
    expect(status.evaluation.samples).toBe(157)
    expect(status.evaluation.valid).toBe(152)
    expect(status.evaluation.accepted).toBe(10)
    expect(status.evaluation.wrongAccepted).toBe(0)
    expect(status.evaluation.userCandidatesCorrect).toBe(7)
    expect(status.evaluation.userAcceptedCorrect).toBe(0)
    expect(status.evaluation.eligible).toBe(false)
    expect("credentialFingerprint" in status).toBe(false)
    expect("identity" in status.evaluation).toBe(false)
    await app.open("/setup/jev")
    await expect(screen.getByRole("status")).toContainText("handwriting check needs more work")
    await expect(screen.getByRole("region", "Latest handwriting evaluation")).toContainText("Jev accepted 10 of 152 valid scores")
    await expect(screen.getByTestId("jev-recommendation")).toContainText("handwriting from more people")
    await app.screenshot("connected-jev-measured-results")
    await screen.getByRole("link", "Back to your game").tap()
    await expect(screen.getByRole("dialog", "Leo")).toBeVisible()
  })

  test("measured results remain accessible in landscape and dark mode", async ({ app, screen, browser }) => {
    await browser.setViewport({ width: 874, height: 402 })
    await browser.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" })
    await app.open("/setup/jev")
    await expect(screen.getByRole("status")).toContainText("handwriting check needs more work")
    const result = screen.getByRole("region", "Latest handwriting evaluation")
    await expect(result).toContainText("Before filtering, its best reading matched 7 of your 8 examples")
    expect(await browser.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    await app.screenshot("measured-jev-results-landscape-dark")
  })
}
