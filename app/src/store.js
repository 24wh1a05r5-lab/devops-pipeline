// Storage layer: Postgres when DATABASE_URL is set, in-memory otherwise.
const { Pool } = require("pg");

function createStore() {
  if (!process.env.DATABASE_URL) {
    const items = [];
    return {
      kind: "memory",
      async init() {},
      async list() { return items; },
      async add(name) { const it = { id: items.length + 1, name }; items.push(it); return it; },
      async ping() { return true; },
    };
  }
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  return {
    kind: "postgres",
    async init() {
      await pool.query("CREATE TABLE IF NOT EXISTS items (id SERIAL PRIMARY KEY, name TEXT NOT NULL)");
    },
    async list() { return (await pool.query("SELECT id, name FROM items ORDER BY id")).rows; },
    async add(name) { return (await pool.query("INSERT INTO items(name) VALUES($1) RETURNING id, name", [name])).rows[0]; },
    async ping() { await pool.query("SELECT 1"); return true; },
  };
}
module.exports = { createStore };
