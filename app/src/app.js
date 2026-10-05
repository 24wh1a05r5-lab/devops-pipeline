const express = require("express");
const client = require("prom-client");

function createApp(store) {
  const app = express();
  app.use(express.json());

  const registry = new client.Registry();
  client.collectDefaultMetrics({ register: registry });
  const httpDuration = new client.Histogram({
    name: "http_request_duration_seconds",
    help: "HTTP request duration",
    labelNames: ["method", "route", "status"],
    buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2],
    registers: [registry],
  });
  app.use((req, res, next) => {
    const end = httpDuration.startTimer();
    res.on("finish", () => end({ method: req.method, route: req.route?.path || req.path, status: res.statusCode }));
    next();
  });

  // Liveness: process is up. Readiness: dependencies reachable.
  app.get("/health", (_req, res) => res.json({ status: "ok", version: process.env.APP_VERSION || "dev" }));
  app.get("/ready", async (_req, res) => {
    try { await store.ping(); res.json({ status: "ready", store: store.kind }); }
    catch { res.status(503).json({ status: "not ready" }); }
  });
  app.get("/metrics", async (_req, res) => {
    res.set("Content-Type", registry.contentType);
    res.end(await registry.metrics());
  });

  app.get("/api/items", async (_req, res) => res.json(await store.list()));
  app.post("/api/items", async (req, res) => {
    const name = req.body?.name;
    if (!name || typeof name !== "string") return res.status(400).json({ error: "name is required" });
    res.status(201).json(await store.add(name));
  });
  return app;
}
module.exports = { createApp };
