import { test } from '@e2e-dev/web'
import { expect } from 'e2e'
import { readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { createHash } from 'node:crypto'

const evidence = process.env.PIPCOUNT_STRESS_EVIDENCE!
type Sample = { id: string; file: string; expected: number | null }

if (evidence) {

test('the running recogniser reports the reviewed candidate and both models', async ({ app }) => {
  const response = await fetch(`${app.baseUrl}/api/recogniser`)
  expect(response.status).toBe(200)
  expect(await response.json()).toEqual({ recogniser: 'digits-6', implementationSHA256: createHash('sha256').update(await readFile('server/recognise.py')).digest('hex'), modelSHA256: '5c688690f8bacf667d4c2074af5ad0646ca328d7ab03eccf944a65b320171bdd', appleModelSHA256: '816d1a222d5272109166ffc819d7ce44aff923a673884e34d982aa74985ba587' })
})

test('transparency, animation and image limits preserve visible input semantics', async ({ app }) => {
  const rows = JSON.parse(await readFile(join(evidence, 'protocol-manifest.json'), 'utf8')) as Sample[]
  const results = []
  for (const sample of rows) {
    const response = await fetch(`${app.baseUrl}/api/recognise`, { method: 'POST', headers: { 'Content-Type': 'image/png' }, body: await readFile(sample.file) })
    expect(response.status, sample.id).toBe(200)
    const result = await response.json()
    results.push({ ...sample, result })
  }
  await writeFile(join(evidence, 'protocol-results.json'), JSON.stringify(results, null, 2))
  for (const row of results) {
    expect(row.result.status, row.id).toBe(row.expected === null ? 'unreadable' : 'ready')
    if (row.expected !== null) expect(row.result.value, row.id).toBe(row.expected)
  }
})

test('malformed requests fail without preventing the next valid score', async ({ app }) => {
  const image = await readFile(join(evidence, 'fixtures/synthetic-24-normal.png'))
  const rows = [
    { name: 'wrong-content-type', body: image, type: 'application/octet-stream' },
    { name: 'empty', body: Buffer.alloc(0), type: 'image/png' },
    { name: 'not-png', body: Buffer.from('not a drawing'), type: 'image/png' },
    { name: 'oversized-payload', body: Buffer.alloc(1048577), type: 'image/png' },
  ]
  for (const row of rows) {
    const response = await fetch(`${app.baseUrl}/api/recognise`, { method: 'POST', headers: { 'Content-Type': row.type }, body: row.body })
    expect(response.status, row.name).toBe(400)
  }
  const response = await fetch(`${app.baseUrl}/api/recognise`, { method: 'POST', headers: { 'Content-Type': 'image/png' }, body: image })
  expect(response.status).toBe(200)
  expect(await response.json()).toMatchObject({ status: 'ready', value: 24 })
})

test('concurrent readers cannot mix score results', { timeout: 60000 }, async ({ app }) => {
  const values = [0,1,3,4,6,7,8,9,10,17,24,37,50,69,72,99]
  const results = await Promise.all(values.map(async value => {
    const response = await fetch(`${app.baseUrl}/api/recognise`, { method: 'POST', headers: { 'Content-Type': 'image/png' }, body: await readFile(join(evidence, `fixtures/synthetic-${value}-normal.png`)) })
    return { expected: value, code: response.status, result: await response.json() }
  }))
  await writeFile(join(evidence, 'concurrency-results.json'), JSON.stringify(results, null, 2))
  expect(results.some(row => row.code === 200)).toBe(true)
  for (const row of results) {
    expect([200,503]).toContain(row.code)
    if (row.code === 200) expect(row.result).toMatchObject({ status: 'ready', value: row.expected })
  }
})
}
