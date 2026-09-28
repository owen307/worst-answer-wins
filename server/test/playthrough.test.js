import assert from "node:assert/strict";
import test from "node:test";
import WebSocket from "ws";
import { startServer } from "../src/index.js";

function collect(ws) {
  const messages = [];
  ws.on("message", (buf) => {
    messages.push(JSON.parse(buf.toString()));
  });
  return {
    messages,
    async waitFor(predicate, timeout = 2000) {
      const started = Date.now();
      while (Date.now() - started < timeout) {
        const found = messages.find(predicate);
        if (found) return found;
        await new Promise((resolve) => setTimeout(resolve, 15));
      }
      throw new Error(`timed out waiting for a message: ${JSON.stringify(messages)}`);
    },
  };
}

function connect(port) {
  const ws = new WebSocket(`ws://127.0.0.1:${port}`);
  const inbox = collect(ws);
  return new Promise((resolve, reject) => {
    ws.once("open", () => resolve({ ws, ...inbox }));
    ws.once("error", reject);
  });
}

function send(ws, message) {
  ws.send(JSON.stringify(message));
}

test("websocket playthrough covers three rounds and the health check", { timeout: 15000 }, async (t) => {
  const running = await startServer({ port: 0, host: "127.0.0.1" });
  const clients = [];
  t.after(async () => {
    for (const client of clients) client.ws.close();
    await running.close();
  });

  const health = await fetch(`http://127.0.0.1:${running.port}/health`);
  assert.equal(health.status, 200);
  assert.equal((await health.json()).ok, true);

  const ava = await connect(running.port);
  const noah = await connect(running.port);
  clients.push(ava, noah);
  send(ava.ws, { type: "create", name: "Ava", rounds: 3 });
  const created = await ava.waitFor((message) => message.type === "state");
  const code = created.room.code;

  send(noah.ws, { type: "join", code, name: "Noah" });
  await noah.waitFor((message) => message.type === "state" && message.room.players.length === 2);
  send(ava.ws, { type: "start" });
  await ava.waitFor((message) => message.room?.phase === "submit");

  const prompts = [];
  for (let round = 1; round <= 3; round += 1) {
    const current = await ava.waitFor(
      (message) => message.room?.phase === "submit" && message.room.round === round,
    );
    prompts.push(current.room.prompt);
    send(ava.ws, { type: "submit", text: `Ava round ${round}` });
    send(noah.ws, { type: "submit", text: `Noah round ${round}` });
    const voting = await ava.waitFor(
      (message) => message.room?.phase === "vote" && message.room.round === round,
    );
    assert.ok(voting.room.answers.every((answer) => answer.authorName == null));
    const avaAnswer = voting.room.answers.find((answer) => answer.yours).id;
    const noahAnswer = voting.room.answers.find((answer) => !answer.yours).id;
    send(ava.ws, { type: "vote", answerId: noahAnswer });
    const noahView = await noah.waitFor(
      (message) => message.room?.phase === "vote" && message.room.round === round,
    );
    const noahOwn = noahView.room.answers.find((answer) => answer.yours).id;
    assert.notEqual(noahOwn, avaAnswer);
    send(noah.ws, { type: "vote", answerId: noahView.room.answers.find((answer) => !answer.yours).id });
    await ava.waitFor((message) => message.room?.phase === "reveal" && message.room.round === round);
    send(ava.ws, { type: "next" });
  }

  const finished = await ava.waitFor((message) => message.room?.phase === "final");
  assert.equal(new Set(prompts).size, 3);
  const scores = Object.fromEntries(finished.room.players.map((player) => [player.name, player.score]));
  assert.deepEqual(scores, { Ava: 3, Noah: 3 });

  send(ava.ws, { type: "not-json-wait" });
  const unknown = await ava.waitFor((message) => message.type === "error");
  assert.match(unknown.message, /Unknown action/);

  ava.ws.send("nope");
  const bad = await ava.waitFor((message) => message.type === "error" && message.message.includes("didn't make sense"));
  assert.ok(bad);
});
