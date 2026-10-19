import { test } from "@e2e-dev/web"
import { expect } from "e2e"
import { execFile } from "node:child_process"
import { readFile, writeFile, mkdir } from "node:fs/promises"
import { promisify } from "node:util"
import { join } from "node:path"

if (process.env.PIPCOUNT_JEV_LIVE === "1") {
  test("measure the connected Jev image reader without activating score acceptance", { timeout: 900000 }, async ({ app }) => {
    const evidence = process.env.PIPCOUNT_JEV_EVIDENCE!
    const manifest = process.env.PIPCOUNT_JEV_MANIFEST!
    const status = await (await fetch(`${app.baseUrl}/api/jev/status`)).json()
    expect(status.configured).toBe(true)
    expect(status.mode).toBe("awaiting_evaluation")
    expect(status.model).toBe("jev-1.14.0")
    await writeFile(join(evidence, "connection-before.json"), JSON.stringify({ configured: status.configured, mode: status.mode, model: status.model, engineering: status.engineering }, null, 2))
    const samples = JSON.parse(await readFile(manifest, "utf8")) as { expected: number | null; userSample?: boolean; file: string }[]
    const first = samples.find(row => row.userSample && row.expected === 3)!
    expect(Boolean(first)).toBe(true)
    const preflight = join(evidence, "preflight")
    await mkdir(preflight, { recursive: true })
    await writeFile(join(preflight, "manifest.json"), JSON.stringify([first]))
    const run = promisify(execFile)
    const python = join(process.cwd(), ".runtime/digits-env/bin/python")
    async function evaluate(file: string, output: string, timeout: number) {
      const result = await run(python, ["server/jev_evaluate.py", "--manifest", file, "--output", output], { cwd: process.cwd(), timeout, maxBuffer: 1048576 })
      await writeFile(join(output, "runner.stdout"), result.stdout)
      await writeFile(join(output, "runner.stderr"), result.stderr)
      return JSON.parse(await readFile(join(output, "evaluation.json"), "utf8"))
    }
    const initial = await evaluate(join(preflight, "manifest.json"), preflight, 45000)
    expect(initial.checks.noProviderErrors).toBe(true)
    const report = await evaluate(manifest, join(evidence, "full-panel"), 780000)
    expect(report.rows.length).toBe(samples.length)
    expect(report.checks.noProviderErrors).toBe(true)
    expect(report.eligible).toBe(false)
    const after = await (await fetch(`${app.baseUrl}/api/jev/status`)).json()
    expect(after.mode).toBe("awaiting_evaluation")
    await writeFile(join(evidence, "connection-after.json"), JSON.stringify({ configured: after.configured, mode: after.mode, model: after.model, engineering: after.engineering }, null, 2))
  })
}
