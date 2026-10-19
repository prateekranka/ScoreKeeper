import { test } from "e2e"
import { expect } from "e2e"
import { execFile } from "node:child_process"
import { readFile, writeFile, mkdir } from "node:fs/promises"
import { promisify } from "node:util"
import { join } from "node:path"

if (process.env.PIPCOUNT_CONTRIBUTED_LOCAL === "1") {
  test("measure contributed handwriting using only the local recognition models", { timeout: 180000 }, async () => {
    const evidence = process.env.PIPCOUNT_JEV_EVIDENCE!
    const manifest = process.env.PIPCOUNT_JEV_MANIFEST!
    const script = process.env.PIPCOUNT_LOCAL_EVALUATOR!
    await mkdir(evidence, { recursive: true })
    const samples = JSON.parse(await readFile(manifest, "utf8")) as { independent: boolean; split: string }[]
    expect(samples.every(row => row.independent === false && row.split === "reviewed-regression")).toBe(true)
    const result = await promisify(execFile)(
      join(process.cwd(), ".runtime/digits-env/bin/python"),
      [script, manifest, evidence],
      { cwd: process.cwd(), timeout: 150000, maxBuffer: 1048576 },
    )
    await writeFile(join(evidence, "runner.stdout"), result.stdout)
    await writeFile(join(evidence, "runner.stderr"), result.stderr)
    const report = JSON.parse(await readFile(join(evidence, "local-evaluation.json"), "utf8"))
    expect(report.rows.length).toBe(samples.length)
    expect(report.rows.every((row: { local: { status: string } }) => ["ready", "unreadable"].includes(row.local.status))).toBe(true)
    expect(report.local.valid).toBe(samples.length)
  })
}
