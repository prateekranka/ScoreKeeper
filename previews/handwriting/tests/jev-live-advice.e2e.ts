import { test } from "@e2e-dev/web"
import { expect } from "e2e"
import { execFile } from "node:child_process"
import { readFile, writeFile } from "node:fs/promises"
import { promisify } from "node:util"
import { join } from "node:path"

if (process.env.PIPCOUNT_JEV_LIVE_ADVICE === "1") {
  test("Jev reviews the measured handwriting evidence before an engineering decision", { timeout: 60000 }, async ({ app, screen }) => {
    const evidence = process.env.PIPCOUNT_JEV_EVIDENCE!
    const reportFile = process.env.PIPCOUNT_JEV_REPORT!
    const report = JSON.parse(await readFile(reportFile, "utf8"))
    expect(report.rows.length).toBeGreaterThan(0)
    const run = promisify(execFile)
    const result = await run(join(process.cwd(), ".runtime/digits-env/bin/python"), ["server/jev_evaluate.py", "--review-report", reportFile, "--output", evidence], { cwd: process.cwd(), timeout: 30000, maxBuffer: 1048576 })
    await writeFile(join(evidence, "engineering-review.stdout"), result.stdout)
    await writeFile(join(evidence, "engineering-review.stderr"), result.stderr)
    const advice = JSON.parse(await readFile(join(evidence, "engineering.json"), "utf8"))
    expect(advice.model).toBe("jev-1.14.0")
    expect(["evaluate_veto", "evaluate_primary", "collect_writers", "retain_local"]).toContain(advice.answers.next_step.choice)
    const status = await (await fetch(`${app.baseUrl}/api/jev/status`)).json()
    expect(status.mode).toBe("awaiting_evaluation")
    expect(status.engineering.choice).toBe(advice.answers.next_step.choice)
    expect(status.evaluation.samples).toBe(report.rows.length)
    await app.open("/setup/jev")
    await expect(screen.getByRole("heading", "Connect Jev to PipCount")).toBeVisible()
    await expect(screen.getByRole("region", "Latest handwriting evaluation")).toContainText(`Jev accepted ${report.jev.accepted} of ${report.jev.valid} valid scores in a comparison of ${report.jev.samples} drawings`)
    await expect(screen.getByTestId("jev-recommendation")).toBeVisible()
    await app.screenshot("jev-contributed-results")
  })
}
