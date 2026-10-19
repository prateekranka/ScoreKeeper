import { test } from '@e2e-dev/web'
import { expect } from 'e2e'
import { request } from 'node:http'

const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==', 'base64')

test('recognition rejects an untrusted browser origin', async ({ app }) => {
  const response = await fetch(`${app.baseUrl}/api/recognise`, { method: 'POST', headers: { 'Content-Type': 'image/png', Origin: 'https://untrusted.example.invalid' }, body: png })
  expect(response.status).toBe(403)
})

test('the configured proxy origin can reach local recognition', async ({ app }) => {
  const response = await fetch(`${app.baseUrl}/api/recognise`, { method: 'POST', headers: { 'Content-Type': 'image/png', Origin: 'https://preview.example.invalid' }, body: png })
  expect(response.status).toBe(200)
  expect(await response.json()).toMatchObject({ status: 'unreadable' })
})

test('an unknown host cannot read the Jev setup token', async ({ app }) => {
  const status = await new Promise<number | undefined>((resolve, reject) => {
    const call = request(`${app.baseUrl}/api/jev/status`, { headers: { Host: 'untrusted.example.invalid' } }, response => {
      response.resume()
      response.on('end', () => resolve(response.statusCode))
    })
    call.on('error', reject)
    call.end()
  })
  expect(status).toBe(403)
})

test('a token does not permit collection writes from an untrusted origin', async ({ app }) => {
  const setup = await (await fetch(`${app.baseUrl}/api/jev/status`)).json()
  const response = await fetch(`${app.baseUrl}/api/handwriting/samples`, { method: 'POST', headers: { 'Content-Type': 'application/json', Origin: 'https://untrusted.example.invalid', 'X-Pipcount-CSRF': setup.csrfToken }, body: '{}' })
  expect(response.status).toBe(403)
})
