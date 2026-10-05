const test = require("node:test");
const assert = require("node:assert");
const { createApp } = require("../src/app");
const { createStore } = require("../src/store");

let server, base;
test.before(async () => {
  server = createApp(createStore()).listen(0);
  base = `http://127.0.0.1:${server.address().port}`;
});
test.after(() => server.close());

test("GET /health returns 200", async () => {
  const r = await fetch(`${base}/health`);
  assert.strictEqual(r.status, 200);
  assert.strictEqual((await r.json()).status, "ok");
});
test("POST then GET /api/items", async () => {
  const p = await fetch(`${base}/api/items`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ name: "widget" }) });
  assert.strictEqual(p.status, 201);
  const items = await (await fetch(`${base}/api/items`)).json();
  assert.strictEqual(items[0].name, "widget");
});
test("POST without name returns 400", async () => {
  const r = await fetch(`${base}/api/items`, { method: "POST", headers: { "content-type": "application/json" }, body: "{}" });
  assert.strictEqual(r.status, 400);
});
test("GET /metrics exposes prometheus format", async () => {
  const t = await (await fetch(`${base}/metrics`)).text();
  assert.match(t, /http_request_duration_seconds/);
});
