import { test, expect } from 'e2e'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import { readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { createHash } from 'node:crypto'

const evidence = process.env.PIPCOUNT_STRESS_EVIDENCE!
const phase = process.env.PIPCOUNT_STRESS_PHASE ?? 'baseline'

if (evidence) {

if (process.env.PIPCOUNT_STRESS_SCREENSHOTS === '1') {
  test('the known screenshot drawings retain their existing readings', { timeout: 120000 }, async () => {
    const result = await promisify(execFile)(join(process.cwd(), '.runtime/digits-env/bin/python'), ['server/local_stress.py', '--root', process.cwd(), '--manifest', join(evidence, 'validation-manifest.json'), '--only', 'screenshot-regression', '--output', join(evidence, `${phase}-screenshots.json`)], { timeout: 100000, maxBuffer: 1048576 })
    await writeFile(join(evidence, `${phase}-screenshots.stdout`), result.stdout)
    const report = JSON.parse(await readFile(join(evidence, `${phase}-screenshots.json`), 'utf8'))
    expect(report.summary.correct).toBe(8)
    expect(report.summary.wrongAccepted).toBe(0)
  })
}

test('visible ink is read and fully transparent ink cannot become a score', { timeout: 120000 }, async () => {
  const result = await promisify(execFile)(join(process.cwd(), '.runtime/digits-env/bin/python'), ['server/local_stress.py', '--root', process.cwd(), '--manifest', join(evidence, 'manifest.json'), '--output', join(evidence, `${phase}-alpha.json`), '--only', 'transparent-visible,transparent-hidden'], { timeout: 100000, maxBuffer: 1048576 })
  await writeFile(join(evidence, `${phase}-alpha.stdout`), result.stdout)
  const report = JSON.parse(await readFile(join(evidence, `${phase}-alpha.json`), 'utf8'))
  expect(report.categories['transparent-hidden'].wrongAccepted).toBe(0)
  expect(report.categories['transparent-visible'].correct).toBeGreaterThanOrEqual(12)
})

if (process.env.PIPCOUNT_STRESS_MEASURE === '1') {
  test('measure deterministic score stress cases without using contributed drawings for tuning', { timeout: 600000 }, async () => {
    const result = await promisify(execFile)(join(process.cwd(), '.runtime/digits-env/bin/python'), ['server/local_stress.py', '--root', process.cwd(), '--manifest', join(evidence, 'manifest.json'), '--output', join(evidence, `${phase}-stress.json`)], { timeout: 540000, maxBuffer: 1048576 })
    await writeFile(join(evidence, `${phase}-stress.stdout`), result.stdout)
    const report = JSON.parse(await readFile(join(evidence, `${phase}-stress.json`), 'utf8'))
    expect(report.rows.length).toBeGreaterThan(1700)
    expect(report.rows.every((row: { result: { status: string } }) => ['ready', 'unreadable'].includes(row.result.status))).toBe(true)
    if (phase === 'final') {
      expect(report.summary.wrongAccepted).toBeLessThanOrEqual(13)
      expect(report.summary.correct).toBeGreaterThanOrEqual(1620)
      expect(report.categories.invalid.wrongAccepted).toBe(0)
      expect(report.categories.left.correct).toBe(100)
      expect(report.categories.right.correct).toBe(100)
      expect(report.categories.close.correct).toBeGreaterThanOrEqual(99)
    }
  })
}

if (process.env.PIPCOUNT_STRESS_FULL === '1') {
  test('measure the exact full MNIST regression set with the strengthened recogniser', { timeout: 600000 }, async () => {
    const result = await promisify(execFile)(join(process.cwd(), '.runtime/digits-env/bin/python'), ['server/local_stress.py', '--root', process.cwd(), '--manifest', join(evidence, 'manifest.json'), '--mnist', process.env.PIPCOUNT_MNIST_MANIFEST!, '--output', join(evidence, `${phase}-mnist.json`)], { timeout: 540000, maxBuffer: 1048576 })
    await writeFile(join(evidence, `${phase}-mnist.stdout`), result.stdout)
    const report = JSON.parse(await readFile(join(evidence, `${phase}-mnist.json`), 'utf8'))
    expect(report.summary.samples).toBe(10000)
    if (phase === 'final') {
      expect(report.summary.wrongAccepted).toBeLessThanOrEqual(16)
      expect(report.summary.correctCoverage).toBeGreaterThanOrEqual(0.90)
    } else {
      expect(report.summary.wrongAccepted).toBeLessThan(16)
      expect(report.summary.correctCoverage).toBeGreaterThanOrEqual(0.89)
    }
  })
}

if (process.env.PIPCOUNT_STRESS_VALIDATE === '1') {
  test('the frozen candidate preserves contributed drawings and original screenshot results', { timeout: 180000 }, async () => {
    const freeze = JSON.parse(await readFile(join(evidence, 'candidate-freeze.json'), 'utf8'))
    expect(createHash('sha256').update(await readFile('server/recognise.py')).digest('hex')).toBe(freeze.recogniserSHA256)
    const result = await promisify(execFile)(join(process.cwd(), '.runtime/digits-env/bin/python'), ['server/local_stress.py', '--root', process.cwd(), '--manifest', join(evidence, 'validation-manifest.json'), '--output', join(evidence, 'validation.json')], { timeout: 150000, maxBuffer: 1048576 })
    await writeFile(join(evidence, 'validation.stdout'), result.stdout)
    const report = JSON.parse(await readFile(join(evidence, 'validation.json'), 'utf8'))
    expect(report.categories['contributed-validation'].samples).toBe(65)
    expect(report.categories['contributed-validation'].wrongAccepted).toBe(0)
    expect(report.categories['contributed-validation'].correct).toBeGreaterThanOrEqual(64)
    expect(report.categories['screenshot-regression'].correct).toBe(8)
    expect(createHash('sha256').update(await readFile('server/recognise.py')).digest('hex')).toBe(freeze.recogniserSHA256)
  })
}
}
