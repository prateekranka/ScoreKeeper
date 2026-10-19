import { test } from "@e2e-dev/web"
import { expect } from "e2e"
import { randomUUID } from "node:crypto"
import { writeFile } from "node:fs/promises"
import { execFile } from "node:child_process"
import { promisify } from "node:util"
import { join } from "node:path"

type Fixtures = Parameters<Parameters<typeof test>[1]>[0]
const ink = [[{ x: 500, y: 200, t: 10, pressure: .5 }, { x: 350, y: 300, t: 20, pressure: .5 }, { x: 300, y: 500, t: 30, pressure: .5 }, { x: 450, y: 700, t: 40, pressure: .5 }, { x: 600, y: 500, t: 50, pressure: .5 }, { x: 500, y: 200, t: 60, pressure: .5 }]]
async function session(base: string | undefined, writer = randomUUID()) {
  const response = await fetch(`${base}/api/handwriting/session?writer=${writer}`)
  expect(response.status).toBe(200)
  return response.json()
}
async function post(base: string | undefined, state: Awaited<ReturnType<typeof session>>, body: Record<string, unknown>, endpoint = "samples") {
  return fetch(`${base}/api/handwriting/${endpoint}`, { method: "POST", headers: { "Content-Type": "application/json", "X-Pipcount-CSRF": state.csrfToken, Origin: base! }, body: JSON.stringify(body) })
}
function body(state: Awaited<ReturnType<typeof session>>, extra: Record<string, unknown> = {}) {
  return { id: randomUUID(), writerId: state.writerId, promptIndex: state.promptIndex, expected: state.expected, strokes: ink, metadata: { width: 402, height: 874, pixelRatio: 2, pointerTypes: ["touch"] }, ...extra }
}
async function draw(browser: Fixtures["browser"]) {
  const m = await browser.evaluate(() => { const value = document.querySelector<SVGSVGElement>('[data-testid="score-canvas"]')!.getScreenCTM()!; return { a: value.a, d: value.d, e: value.e, f: value.f } })
  const [start, ...rest] = ink[0]
  await browser.mouse.move(m.e + start.x * m.a, m.f + start.y * m.d)
  await browser.mouse.down()
  for (const point of rest) await browser.mouse.move(m.e + point.x * m.a, m.f + point.y * m.d)
  await browser.mouse.up()
}

if (process.env.PIPCOUNT_COLLECTION_QA === "1") {
  test("a drawn sample saves once, advances and can be restored with Undo", async ({ app, screen, browser }) => {
    await app.open("/handwriting")
    await expect(screen.getByRole("heading", "Show us how you write")).toBeVisible()
    await expect(screen.getByTestId("sample-expected")).toHaveText("0")
    await expect(screen.getByRole("button", "Save sample", { exact: true })).toBeDisabled()
    await draw(browser)
    await screen.getByRole("button", "Save sample", { exact: true }).tap()
    await expect(screen.getByRole("status")).toContainText("Your 0 has been saved")
    await expect(screen.getByTestId("sample-expected")).toHaveText("1")
    await expect(screen.getByTestId("writer-progress")).toContainText("saved 1 of 40")
    await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "0")
    await app.screenshot("first-handwriting-sample-saved")
    await screen.getByRole("button", "Undo last saved sample", { exact: true }).tap()
    await expect(screen.getByTestId("sample-expected")).toHaveText("0")
    await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "1")
    await expect(screen.getByTestId("writer-progress")).toContainText("saved 0 of 40")
    await screen.getByRole("button", "Save sample", { exact: true }).tap()
    await expect(screen.getByTestId("writer-progress")).toContainText("saved 1 of 40")
  })

  test("each writer keeps their draft across switching, reload and rotation", async ({ app, screen, browser }) => {
    await app.open("/handwriting")
    await expect(screen.getByRole("status")).toContainText("Check that your drawing")
    await draw(browser)
    await screen.getByRole("button", "New writer", { exact: true }).tap()
    expect(await browser.evaluate(() => (document.querySelector('#sample-writer') as HTMLSelectElement).selectedOptions[0].textContent)).toBe("Writer 2")
    await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "0")
    await screen.getByLabel("Who’s writing?").selectOption({ label: "Writer 1" })
    await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "1")
    await browser.reload()
    await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "1")
    await browser.setViewport({ width: 874, height: 402 })
    await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "1")
    await browser.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" })
    expect(await browser.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    expect(await browser.evaluate(() => [...document.querySelectorAll('.sample-action-row button')].every(element => { const box = element.getBoundingClientRect(); return box.width >= 44 && box.height >= 44 }))).toBe(true)
    await app.screenshot("handwriting-collection-landscape-dark")
    await screen.getByRole("button", "Clear drawing", { exact: true }).tap()
    await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "0")
  })

  test("an uncertain network save can be retried without collecting the same drawing twice", async ({ app }) => {
    const state = await session(app.baseUrl)
    const payload = body(state)
    const responses = await Promise.all([post(app.baseUrl, state, payload), post(app.baseUrl, state, payload)])
    for (const response of responses) expect(response.status).toBe(200)
    const receipts = await Promise.all(responses.map(response => response.json()))
    expect(receipts.filter(receipt => receipt.created).length).toBe(1)
    const after = await session(app.baseUrl, state.writerId)
    expect(after.writerSaved).toBe(1)
    expect(after.totalSaved).toBe(state.totalSaved + 1)
    expect(after.expected).toBe(1)
    const replay = await post(app.baseUrl, state, payload)
    expect(replay.status).toBe(200)
    expect((await replay.json()).created).toBe(false)
  })

  test("a lost response recovers the saved receipt and clears only the already saved draft", async ({ app, screen, browser }) => {
    await app.open("/handwriting")
    await expect(screen.getByRole("status")).toContainText("Check that your drawing")
    await draw(browser)
    let captured: Record<string, unknown> | undefined
    await browser.route('**/api/handwriting/samples', async route => { captured = JSON.parse(route.request.postData!); await route.fulfill({ status: 503, json: { reason: "test-network" } }) })
    await screen.getByRole("button", "Save sample", { exact: true }).tap()
    await expect(screen.getByRole("status")).toContainText("drawing is still here")
    const state = await session(app.baseUrl, captured!.writerId as string)
    expect((await post(app.baseUrl, state, captured!)).status).toBe(200)
    await browser.reload()
    await expect(screen.getByTestId("sample-expected")).toHaveText("1")
    await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "0")
    await expect(screen.getByTestId("writer-progress")).toContainText("saved 1 of 40")
  })

  test("a refreshed server connection preserves the drawing for a safe retry", async ({ app, screen, browser }) => {
    await app.open("/handwriting")
    await expect(screen.getByRole("status")).toContainText("Check that your drawing")
    await draw(browser)
    let first = true
    await browser.route("**/api/handwriting/samples", async route => {
      if (first) { first = false; await route.continue({ headers: { ...route.request.headers, "x-pipcount-csrf": "stale-token" } }) }
      else await route.continue()
    })
    await screen.getByRole("button", "Save sample", { exact: true }).tap()
    await expect(screen.getByRole("status")).toContainText("connection has been refreshed")
    await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "1")
    await screen.getByRole("button", "Save sample", { exact: true }).tap()
    await expect(screen.getByTestId("writer-progress")).toContainText("saved 1 of 40")
  })

  test("another tab cannot silently relabel a draft with a new score", async ({ app, screen, browser }) => {
    await app.open("/handwriting")
    await expect(screen.getByRole("status")).toContainText("Check that your drawing")
    await draw(browser)
    await expect.poll(() => browser.evaluate(() => { const data = JSON.parse(localStorage.getItem("pipcount-handwriting-collection-v1") ?? "null"); return data?.writers.find((writer: { id: string }) => writer.id === data.current)?.draft.strokes.length ?? 0 })).toBe(1)
    const stored = await browser.evaluate(() => JSON.parse(localStorage.getItem('pipcount-handwriting-collection-v1')!))
    const state = await session(app.baseUrl, stored.current)
    expect((await post(app.baseUrl, state, body(state))).status).toBe(200)
    await browser.reload()
    await expect(screen.getByTestId("sample-expected")).toHaveText("0")
    await expect(screen.getByRole("status")).toContainText("another tab")
    await expect(screen.getByRole("button", "Save sample", { exact: true })).toBeDisabled()
    await expect(screen.getByTestId("score-canvas")).toHaveAttribute("data-stroke-count", "1")
    await screen.getByRole("button", "Clear drawing", { exact: true }).tap()
    await expect(screen.getByTestId("sample-expected")).toHaveText("1")
  })

  test("the exporter keeps labelled images and raw strokes and omits undone samples", async ({ app }) => {
    const state = await session(app.baseUrl)
    const payload = body(state)
    const first = await (await post(app.baseUrl, state, payload)).json()
    const secondState = await session(app.baseUrl, state.writerId)
    const secondPayload = body(secondState)
    expect((await post(app.baseUrl, secondState, secondPayload)).status).toBe(200)
    expect((await post(app.baseUrl, secondState, { writerId: state.writerId, id: secondPayload.id }, "undo")).status).toBe(200)
    expect((await post(app.baseUrl, secondState, { writerId: state.writerId, id: secondPayload.id }, "undo")).status).toBe(200)
    expect((await session(app.baseUrl, state.writerId)).writerSaved).toBe(1)
    const response = await fetch(`${app.baseUrl}/api/handwriting/export`)
    expect(response.status).toBe(200)
    expect(response.headers.get('Content-Type')).toBe('application/zip')
    const file = join(process.env.PIPCOUNT_COLLECTION_EVIDENCE!, 'qa-export.zip')
    await writeFile(file, Buffer.from(await response.arrayBuffer()))
    const { stdout } = await promisify(execFile)(join(process.cwd(), '.runtime/digits-env/bin/python'), ['-c', 'import json,zipfile,sys; from PIL import Image; z=zipfile.ZipFile(sys.argv[1]); rows=json.loads(z.read("manifest.json")); row=next(r for r in rows if r["id"]==sys.argv[2]); drawing=Image.open(z.open(row["file"])); ink=json.loads(z.read(row["rawStrokes"])); print(json.dumps({"expected":row["expected"],"writer":row["writer"],"split":row["split"],"independent":row["independent"],"size":drawing.size,"points":len(ink["strokes"][0]),"timing":ink["strokes"][0][0]["t"],"undonePresent":any(r["id"]==sys.argv[3] for r in rows),"provenance":json.loads(z.read("provenance.json"))}))', file, payload.id as string, secondPayload.id as string])
    const exported = JSON.parse(stdout)
    expect(exported.expected).toBe(0)
    expect(exported.writer).toBe(state.writerId)
    expect(exported.split).toBe('unreviewed')
    expect(exported.independent).toBe(false)
    expect(exported.points).toBe(6)
    expect(exported.timing).toBe(10)
    expect(exported.undonePresent).toBe(false)
    expect(exported.provenance.modelCallsDuringCollection).toBe(0)
    expect(Math.max(...exported.size)).toBe(640)
    expect(first.created).toBe(true)
  })

  for (const [name, edit, expected] of [
    ["blank", { strokes: [] }, 400],
    ["tap only", { strokes: [[{ x: 5, y: 5 }]] }, 400],
    ["outside canvas", { strokes: [[{ x: 1001, y: 1 }, { x: 1, y: 9 }]] }, 400],
    ["invalid pressure", { strokes: [[{ x: 5, y: 5, pressure: 2 }, { x: 5, y: 9 }]] }, 400],
    ["wrong label", { expected: 9 }, 409],
    ["invalid identifier", { id: "not-a-uuid" }, 400],
  ] as const) {
    test(`the collection rejects ${name} input without saving it`, async ({ app }) => {
      const state = await session(app.baseUrl)
      expect((await post(app.baseUrl, state, body(state, edit))).status).toBe(expected)
      expect((await session(app.baseUrl, state.writerId)).writerSaved).toBe(0)
    })
  }

  test("the collection rejects wrong origins and CSRF tokens", async ({ app }) => {
    const state = await session(app.baseUrl)
    for (const headers of [{ Origin: 'https://unrelated.invalid', 'X-Pipcount-CSRF': state.csrfToken }, { Origin: app.baseUrl!, 'X-Pipcount-CSRF': 'wrong' }]) {
      const response = await fetch(`${app.baseUrl}/api/handwriting/samples`, { method: 'POST', headers: { ...headers, 'Content-Type': 'application/json' }, body: JSON.stringify(body(state)) })
      expect(response.status).toBe(403)
    }
    expect((await session(app.baseUrl, state.writerId)).writerSaved).toBe(0)
  })
}
