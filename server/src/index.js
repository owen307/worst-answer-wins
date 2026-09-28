import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { WebSocketServer } from "ws";
import { createGame } from "./game.js";

const LANDING_HTML = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Worst Answer Wins</title>
  <style>
    body { font-family: Georgia, serif; background: #fff4e4; color: #241c33; margin: 0; }
    main { max-width: 36rem; margin: 0 auto; padding: 2.5rem 1.25rem; }
    h1 { font-size: 2.4rem; margin-bottom: 0.25rem; }
    code { background: #fff; padding: 0.1rem 0.35rem; border-radius: 0.4rem; }
  </style>
</head>
<body>
  <main>
    <h1>Worst Answer Wins</h1>
    <p>This is the realtime room server. Play in the Flutter app or the web build, then point it at <code>ws://this-computer:8787</code>.</p>
    <p>Health check: <a href="/health">/health</a></p>
  </main>
</body>
</html>`;

export function startServer({ port = 8787, host = "0.0.0.0", game = createGame() } = {}) {
  const server = http.createServer((req, res) => {
    if (req.url === "/health") {
      res.writeHead(200, { "content-type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ ok: true, rooms: game.roomCount() }));
      return;
    }
    res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
    res.end(LANDING_HTML);
  });

  const wss = new WebSocketServer({ server });
  wss.on("connection", (ws) => {
    ws.on("message", (data) => {
      const raw = typeof data === "string" ? data : data.toString();
      if (raw.length > 8000) {
        ws.send(JSON.stringify({ type: "error", message: "That message was too big." }));
        return;
      }
      let msg;
      try {
        msg = JSON.parse(raw);
      } catch {
        ws.send(JSON.stringify({ type: "error", message: "That message didn't make sense." }));
        return;
      }
      game.handle(ws, msg);
    });
    ws.on("close", () => game.disconnect(ws));
  });

  const timer = setInterval(() => game.sweep(), 60 * 1000);
  timer.unref?.();

  return new Promise((resolve) => {
    server.listen(port, host, () => {
      const address = server.address();
      resolve({
        server,
        wss,
        game,
        port: typeof address === "object" && address ? address.port : port,
        close: () =>
          new Promise((done) => {
            clearInterval(timer);
            for (const client of wss.clients) {
              client.terminate();
            }
            wss.close();
            server.close(() => done());
            setTimeout(done, 1000).unref?.();
          }),
      });
    });
  });
}

const invokedDirectly =
  process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (invokedDirectly) {
  const port = Number(process.env.PORT) || 8787;
  startServer({ port }).then(({ port: listening }) => {
    console.log(`Worst Answer Wins server listening on http://0.0.0.0:${listening}`);
  });
}
