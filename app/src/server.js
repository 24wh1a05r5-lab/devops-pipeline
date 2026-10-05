const { createApp } = require("./app");
const { createStore } = require("./store");

(async () => {
  const store = createStore();
  await store.init();
  const port = process.env.PORT || 3000;
  const server = createApp(store).listen(port, () => console.log(`listening on ${port} (store=${store.kind})`));
  process.on("SIGTERM", () => server.close(() => process.exit(0)));
})().catch((e) => { console.error(e); process.exit(1); });
