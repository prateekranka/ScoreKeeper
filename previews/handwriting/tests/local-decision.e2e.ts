import { test, expect } from 'e2e'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import { readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'

if (process.env.PIPCOUNT_STRESS_ADVICE === '1') {
test('Jev reviews the measured local candidate using aggregates only', { timeout: 45000 }, async () => {
  const evidence = process.env.PIPCOUNT_STRESS_EVIDENCE!
  const result = await promisify(execFile)(join(process.cwd(), '.runtime/digits-env/bin/python'), [join(evidence, 'advise.py')], { timeout: 30000, maxBuffer: 1048576 })
  await writeFile(join(evidence, 'advice.stdout'), result.stdout)
  const review = JSON.parse(await readFile(join(evidence, 'local-engineering-advice.json'), 'utf8'))
  const input = JSON.parse(await readFile(join(evidence, 'local-engineering-input.json'), 'utf8'))
  expect(review.model).toBe('jev-1.14.0')
  expect(['deploy_measured_candidate', 'measure_components_only', 'retain_baseline']).toContain(review.answers.next_step.choice)
  expect(input.reserved_user_validation['contributed-validation'].samples).toBe(65)
  expect(input.candidate_full_mnist.samples).toBe(10000)
})
}
