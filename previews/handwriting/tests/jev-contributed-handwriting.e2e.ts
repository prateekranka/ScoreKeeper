import { test } from "@e2e-dev/web"
import { expect } from "e2e"
import { execFile } from "node:child_process"
import { readFile, writeFile, mkdir } from "node:fs/promises"
import { promisify } from "node:util"
import { join } from "node:path"

if (process.env.PIPCOUNT_CONTRIBUTED_PANEL === "1") {
  test("measure frozen contributed handwriting without changing recognition policy", { timeout: 900000 }, async ({ app }) => {
    const evidence = process.env.PIPCOUNT_JEV_EVIDENCE!
    const manifest = process.env.PIPCOUNT_JEV_MANIFEST!
    const status = await (await fetch(`${app.baseUrl}/api/jev/status`)).json()
    expect(status.configured).toBe(true)
    expect(status.mode).toBe("awaiting_evaluation")
    expect(status.model).toBe("jev-1.14.0")
    const identity = { configured: status.configured, mode: status.mode, model: status.model }
    await mkdir(evidence, { recursive: true })
    await writeFile(join(evidence, "connection-before.json"), JSON.stringify(identity, null, 2))
    const samples = JSON.parse(await readFile(manifest, "utf8")) as { independent: boolean; split: string; expected: number; imageSHA256: string }[]
    expect(samples.length).toBeGreaterThan(0)
    expect(samples.length).toBeLessThanOrEqual(220)
    expect(samples.every(row => row.independent === false && row.split === "reviewed-regression")).toBe(true)
    expect(new Set(samples.map(row => row.imageSHA256)).size).toBe(samples.length)
    const result = await promisify(execFile)(
      join(process.cwd(), ".runtime/digits-env/bin/python"),
      ["server/jev_evaluate.py", "--manifest", manifest, "--output", evidence],
      { cwd: process.cwd(), timeout: 780000, maxBuffer: 1048576 },
    )
    await writeFile(join(evidence, "runner.stdout"), result.stdout)
    await writeFile(join(evidence, "runner.stderr"), result.stderr)
    const report = JSON.parse(await readFile(join(evidence, "evaluation.json"), "utf8"))
    expect(report.rows.length).toBe(samples.length)
    expect(report.checks.noProviderErrors).toBe(true)
    expect(report.holdout.samples).toBe(0)
    expect(report.eligible).toBe(false)
    const after = await (await fetch(`${app.baseUrl}/api/jev/status`)).json()
    expect({ configured: after.configured, mode: after.mode, model: after.model }).toEqual(identity)
    await writeFile(join(evidence, "connection-after.json"), JSON.stringify(identity, null, 2))
  })
}
