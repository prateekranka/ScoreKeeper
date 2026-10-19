import { test } from "@e2e-dev/web"
import { expect } from "e2e"

test("the private preview offers Jev setup while keeping local recognition active", async ({ app, screen }) => {
  const response = await fetch(`${app.baseUrl}/api/jev/status`)
  const status = await response.json()
  expect(response.status).toBe(200)
  expect(status.configured).toBe(false)
  expect(status.mode).toBe("local")
  expect(status.model).toBe("jev-1.14.0")
  await app.open("/setup/jev")
  await expect(screen.getByRole("heading", "Connect Jev to PipCount")).toBeVisible()
  await expect(screen.getByRole("status")).toContainText("using local recognition")
  await expect(screen.getByLabel("TypeSafe API key")).toBeVisible()
  await expect(screen.getByRole("button", "Connect Jev", { exact: true })).toBeDisabled()
  await app.screenshot("private-jev-setup-ready-for-key")
  await screen.getByRole("link", "Back to your game").tap()
  await expect(screen.getByRole("dialog", "Leo")).toBeVisible()
})

test("the production preview exposes no simulated upstream controls", async ({ app }) => {
  for (const endpoint of ["/api/test/jev", "/api/test/evaluate"]) {
    expect((await fetch(`${app.baseUrl}${endpoint}`)).status).toBe(404)
    expect((await fetch(`${app.baseUrl}${endpoint}`, { method: "POST" })).status).toBe(404)
  }
  const response = await fetch(`${app.baseUrl}/api/jev/status`)
  expect(response.headers.get("Cache-Control")).toBe("no-store")
  expect(response.headers.get("Content-Security-Policy")).toBe("frame-ancestors 'none'")
  const body = await response.text()
  expect(body.includes("credentialFingerprint")).toBe(false)
  expect(body.includes("apiKey")).toBe(false)
})
