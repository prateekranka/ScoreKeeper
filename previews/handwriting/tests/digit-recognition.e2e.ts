import { test } from "@e2e-dev/web"
import { expect } from "e2e"
import { readFile, writeFile } from "node:fs/promises"
import { createHash } from "node:crypto"

const evidence = process.env.PIPCOUNT_DIGIT_EVIDENCE!

test("the user's actual digit samples are recognised correctly", async ({ app }) => {
  const samples = JSON.parse(await readFile(`${evidence}/user-fixtures.json`, "utf8")) as { file: string; expected: number }[]
  const results = []
  for (const sample of samples) {
    const image = await readFile(sample.file)
    const start = Date.now()
    const response = await fetch(`${app.baseUrl}/api/recognise`, { method: "POST", headers: { "Content-Type": "image/png" }, body: image })
    const result = await response.json()
    results.push({ sample: sample.file, expected: sample.expected, result, milliseconds: Date.now() - start })
  }
  await writeFile(`${evidence}/user-results-${process.env.PIPCOUNT_RUN_LABEL ?? 'current'}.json`, JSON.stringify(results, null, 2))
  for (const row of results) {
    expect(row.result.status, row.sample).toBe("ready")
    expect(row.result.value, row.sample).toBe(row.expected)
  }
})

type Fixtures = Parameters<Parameters<typeof test>[1]>[0]

const digits: number[][][][] = [
  [[[500,200],[400,210],[330,270],[290,370],[280,500],[300,610],[360,690],[450,710],[540,670],[600,590],[640,480],[650,370],[630,280],[570,220],[500,200]]],
  [[[390,320],[500,210],[500,700]],[[350,700],[650,700]]],
  [[[300,310],[320,260],[390,220],[490,210],[580,250],[610,320],[580,400],[500,480],[410,560],[300,690],[630,690]]],
  [[[310,290],[390,220],[500,200],[590,220],[620,270],[600,330],[530,400],[420,460],[520,440],[590,450],[610,500],[570,590],[490,660],[400,700],[320,690],[300,660]]],
  [[[560,200],[300,500],[650,500]],[[560,200],[560,710]]],
  [[[620,210],[340,210],[310,450],[420,410],[530,420],[610,490],[620,580],[570,660],[470,700],[360,690],[300,650]]],
  [[[610,210],[530,240],[430,310],[350,410],[310,520],[320,620],[380,690],[470,700],[560,660],[600,590],[590,520],[530,480],[430,470],[320,490]]],
  [[[300,210],[640,210],[590,300],[530,400],[470,510],[410,620],[380,710]]],
  [[[480,440],[390,400],[340,330],[360,250],[430,210],[520,220],[580,280],[570,350],[510,420],[420,470],[340,550],[330,620],[390,690],[490,710],[590,660],[610,580],[560,500],[480,440]]],
  [[[600,440],[520,480],[420,480],[340,430],[310,350],[330,270],[410,220],[520,220],[600,280],[610,400],[610,530],[600,700]]],
]

async function draw(browser: Fixtures["browser"], paths: number[][][]) {
  await expect.poll(() => browser.evaluate(() => document.getAnimations().every(a => a.playState !== "running"))).toBe(true)
  const m = await browser.evaluate(() => {
    const matrix = document.querySelector<SVGSVGElement>('[data-testid="score-canvas"]')!.getScreenCTM()!
    return { a: matrix.a, d: matrix.d, e: matrix.e, f: matrix.f }
  })
  for (const [start, ...rest] of paths) {
    await browser.mouse.move(m.e + start[0] * m.a, m.f + start[1] * m.d)
    await browser.mouse.down()
    for (const point of rest) await browser.mouse.move(m.e + point[0] * m.a, m.f + point[1] * m.d)
    await browser.mouse.up()
  }
}

for (const value of [0,1,2,3,4,5,6,7,8,9,10,11,12,17,18,19,20,25,37,41,50,69,72,90,91,99]) {
  test(`drawing ${value} is read as ${value} and saved with one tap`, async ({ app, screen, browser }) => {
    await app.open('/?state=write&preset=softer')
    const characters = String(value).split('').map(Number)
    const paths = characters.flatMap((digit, index) => digits[digit].map(stroke => stroke.map(([x,y]) => characters.length === 1 ? [x,y] : [x * 0.65 + (index === 0 ? -110 : 370), y])))
    await draw(browser, paths)
    await expect(screen.getByTestId('recognition-status')).toContainText(`A score of ${value} will`, { timeout: 10000 })
    await expect(screen.getByTestId('recognition-status')).toContainText(`Leo’s total to ${9 + value}`)
    await screen.getByRole('button', 'Save score').tap()
    await expect(screen.getByRole('dialog', 'Maya')).toBeVisible()
    await expect(screen.getByTestId('score-toast')).toContainText(`Leo’s total is now ${9 + value}`)
    if ([0,3,8,17,99].includes(value)) await app.screenshot(`recognised-and-saved-${value}`)
  })
}

if (process.env.PIPCOUNT_BENCHMARK === '1') {
  test('measure the complete MNIST test set through the recognition API', { timeout: 180000 }, async ({ app }) => {
    const samples = JSON.parse(await readFile(`${evidence}/mnist-test.json`, 'utf8')) as { index: number; expected: number; png: string }[]
    const wrong = []
    let accepted = 0
    const start = Date.now()
    for (const sample of samples) {
      const response = await fetch(`${app.baseUrl}/api/recognise`, { method: 'POST', headers: { 'Content-Type': 'image/png' }, body: Buffer.from(sample.png, 'base64') })
      const result = await response.json()
      expect(response.status).toBe(200)
      if (result.status === 'ready') {
        accepted++
        if (result.value !== sample.expected) wrong.push({ index: sample.index, expected: sample.expected, result })
      }
    }
    const report = { source: 'MNIST t10k, all 10000 test samples, enlarged ten times before sending to the same API', total: samples.length, accepted, rejected: samples.length - accepted, wrongAccepted: wrong.length, zeroWrongAccepted: wrong.length === 0, acceptedPrecision: (accepted - wrong.length) / accepted, coverage: accepted / samples.length, milliseconds: Date.now() - start, wrong }
    await writeFile(`${evidence}/benchmark-${process.env.PIPCOUNT_RUN_LABEL ?? 'current'}.json`, JSON.stringify(report, null, 2))
    expect(report.acceptedPrecision).toBeGreaterThanOrEqual(0.995)
    expect(report.coverage).toBeGreaterThanOrEqual(0.90)
  })
}

test('blank, negative, three digits and a scribble do not enable saving', async ({ app }) => {
  const samples = JSON.parse(await readFile(`${evidence}/control-fixtures.json`, 'utf8')) as { file: string; name: string }[]
  const results = []
  for (const sample of samples) {
    const response = await fetch(`${app.baseUrl}/api/recognise`, { method: 'POST', headers: { 'Content-Type': 'image/png' }, body: await readFile(sample.file) })
    results.push({ name: sample.name, result: await response.json() })
  }
  await writeFile(`${evidence}/controls-${process.env.PIPCOUNT_RUN_LABEL ?? 'current'}.json`, JSON.stringify(results, null, 2))
  for (const row of results) expect(row.result.status, row.name).toBe('unreadable')
})

test('the active recogniser has both reviewed models', async ({ app }) => {
  const response = await fetch(`${app.baseUrl}/api/recogniser`)
  expect(response.status).toBe(200)
    expect(await response.json()).toEqual({ recogniser: 'digits-6', implementationSHA256: createHash('sha256').update(await readFile('server/recognise.py')).digest('hex'), modelSHA256: '5c688690f8bacf667d4c2074af5ad0646ca328d7ab03eccf944a65b320171bdd', appleModelSHA256: '816d1a222d5272109166ffc819d7ce44aff923a673884e34d982aa74985ba587' })
})


test('stray marks beside a digit cannot become an extra score digit', async ({ app }) => {
  const previous = process.env.PIPCOUNT_PREVIOUS_DIGIT_EVIDENCE!
  const rows = JSON.parse(await readFile(`${previous}/benchmark-shared-final.json`, 'utf8')).wrong as { index: number; expected: number; result: { value: number } }[]
  const samples = JSON.parse(await readFile(`${evidence}/mnist-test.json`, 'utf8')) as { index: number; expected: number; png: string }[]
  const results = []
  for (const row of rows.filter(row => row.result.value >= 10)) {
    const response = await fetch(`${app.baseUrl}/api/recognise`, { method: 'POST', headers: { 'Content-Type': 'image/png' }, body: Buffer.from(samples[row.index].png, 'base64') })
    const result = await response.json()
    results.push({ index: row.index, expected: row.expected, result })
    expect(response.status).toBe(200)
  }
  await writeFile(`${evidence}/segmentation-regressions-${process.env.PIPCOUNT_RUN_LABEL ?? 'current'}.json`, JSON.stringify(results, null, 2))
  for (const row of results) expect(row.result.status === 'unreadable' || row.result.value === row.expected, `sample ${row.index}`).toBe(true)
})
