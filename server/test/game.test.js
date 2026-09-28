import assert from "node:assert/strict";
import test from "node:test";
import { createGame } from "../src/game.js";
import { PROMPTS } from "../src/prompts.js";

const BANNED = [
  "sex",
  "sexy",
  "damn",
  "hell",
  "crap",
  "piss",
  "fuck",
  "shit",
  "bitch",
  "ass",
  "nude",
  "beer",
  "wine",
  "kill",
  "death",
  "blood",
  "drug",
];

function fakeWs() {
  return {
    readyState: 1,
    sent: [],
    send(data) {
      this.sent.push(JSON.parse(data));
    },
    close() {
      this.readyState = 3;
    },
  };
}

function stateOf(ws) {
  const states = ws.sent.filter((message) => message.type === "state");
  assert.ok(states.length > 0, "expected a room state");
  return states[states.length - 1].room;
}

function errorsOf(ws) {
  return ws.sent.filter((message) => message.type === "error").map((message) => message.message);
}

function setup(overrides = {}) {
  let nextCode = 0;
  const codes = ["ROOM", "BETA", "GAME", "PLAY", "PARTY", "FUNK"];
  const game = createGame({
    codeFactory: () => {
      const code = codes[nextCode] ?? `R${nextCode}`;
      nextCode += 1;
      return code;
    },
    ...overrides,
  });
  return game;
}

test("starter deck is a unique family-friendly set of 20–40 prompts", () => {
  assert.ok(PROMPTS.length >= 20 && PROMPTS.length <= 40, PROMPTS.length);
  assert.equal(new Set(PROMPTS).size, PROMPTS.length);
  for (const prompt of PROMPTS) {
    assert.equal(typeof prompt, "string");
    assert.ok(prompt.endsWith("?"), prompt);
    const words = prompt.toLowerCase().split(/[^a-z]+/);
    for (const banned of BANNED) {
      assert.ok(!words.includes(banned), `${prompt} contains ${banned}`);
    }
  }
});

test("host creates a room and a second player joins with a code", () => {
  const game = setup();
  const host = fakeWs();
  const guest = fakeWs();
  game.handle(host, { type: "create", name: "Ava", rounds: 3 });
  const created = stateOf(host);
  assert.equal(created.code, "ROOM");
  assert.equal(created.phase, "lobby");
  assert.equal(created.you.isHost, true);
  assert.equal(created.totalRounds, 3);

  game.handle(guest, { type: "join", code: "room", name: "Noah" });
  const joined = stateOf(guest);
  assert.equal(joined.code, "ROOM");
  assert.equal(joined.you.isHost, false);
  assert.deepEqual(
    joined.players.map((player) => player.name),
    ["Ava", "Noah"],
  );
  assert.equal(stateOf(host).players.length, 2);
});

test("room rejects a full house, duplicate names, and a solo start", () => {
  const game = setup();
  const host = fakeWs();
  game.handle(host, { type: "create", name: "Ava", rounds: 5 });
  game.handle(host, { type: "start" });
  assert.match(errorsOf(host).at(-1), /at least 2/);

  const same = fakeWs();
  game.handle(same, { type: "join", code: "ROOM", name: "ava" });
  assert.match(errorsOf(same).at(-1), /already has that name/);

  const names = ["Mia", "Leo", "Eva", "Sam", "Joy", "Ben", "Ivy", "Kai"];
  const sockets = names.map((name) => {
    const ws = fakeWs();
    game.handle(ws, { type: "join", code: "ROOM", name });
    return ws;
  });
  assert.match(errorsOf(sockets.at(-1)).at(-1), /full/);
  assert.equal(stateOf(host).players.length, 8);

  const missing = fakeWs();
  game.handle(missing, { type: "join", code: "NOPE", name: "Ada" });
  assert.match(errorsOf(missing).at(-1), /No room/);
});

test("a three-round game scores votes and keeps authors hidden until the reveal", () => {
  const game = setup();
  const ava = fakeWs();
  const noah = fakeWs();
  const mia = fakeWs();
  game.handle(ava, { type: "create", name: "Ava", rounds: 3 });
  game.handle(noah, { type: "join", code: "ROOM", name: "Noah" });
  game.handle(mia, { type: "join", code: "ROOM", name: "Mia" });
  game.handle(ava, { type: "start" });

  const seen = [];
  const expected = [
    [
      ["Ava", "Noah"],
      ["Noah", "Mia"],
      ["Mia", "Ava"],
    ],
    [
      ["Ava", "Noah"],
      ["Noah", "Ava"],
      ["Mia", "Ava"],
    ],
    [
      ["Ava", "Mia"],
      ["Noah", "Mia"],
      ["Mia", "Ava"],
    ],
  ];

  for (let round = 0; round < 3; round += 1) {
    const prompt = stateOf(ava).prompt;
    assert.equal(stateOf(ava).phase, "submit");
    assert.equal(stateOf(ava).round, round + 1);
    assert.ok(!seen.includes(prompt));
    seen.push(prompt);
    assert.equal(stateOf(ava).answers.length, 0);

    const answers = ["Ava's bit", "Noah's bit", "Mia's bit"];
    game.handle(ava, { type: "submit", text: answers[0] });
    game.handle(noah, { type: "submit", text: answers[1] });
    assert.equal(stateOf(mia).phase, "submit");
    game.handle(mia, { type: "submit", text: answers[2] });

    const voting = stateOf(ava);
    assert.equal(voting.phase, "vote");
    for (const answer of voting.answers) {
      assert.equal(answer.authorName, null);
      assert.equal(answer.votes, 0);
    }
    const own = voting.answers.find((answer) => answer.yours);
    game.handle(ava, { type: "vote", answerId: own.id });
    assert.match(errorsOf(ava).at(-1), /own answer/);
    assert.equal(stateOf(ava).phase, "vote");

    const byName = Object.fromEntries(
      [ava, noah, mia].map((ws) => {
        const room = stateOf(ws);
        const id = room.answers.find((answer) => answer.yours).id;
        return [room.you.name, id];
      }),
    );
    for (const [voterName, targetName] of expected[round]) {
      const voter = { Ava: ava, Noah: noah, Mia: mia }[voterName];
      game.handle(voter, { type: "vote", answerId: byName[targetName] });
    }

    const reveal = stateOf(ava);
    assert.equal(reveal.phase, "reveal");
    assert.ok(reveal.answers.every((answer) => answer.authorName));
    game.handle(ava, { type: "next" });
  }

  const finalState = stateOf(ava);
  assert.equal(finalState.phase, "final");
  const scores = Object.fromEntries(finalState.players.map((player) => [player.name, player.score]));
  // Round 1: each answer gets 1 vote. Round 2: Ava 2, Noah 1. Round 3: Mia 2, Ava 1.
  assert.deepEqual(scores, { Ava: 4, Noah: 2, Mia: 3 });
  assert.equal(finalState.players[0].name, "Ava");

  game.handle(noah, { type: "again" });
  assert.match(errorsOf(noah).at(-1), /host/i);
  game.handle(ava, { type: "again" });
  const lobby = stateOf(mia);
  assert.equal(lobby.phase, "lobby");
  assert.ok(lobby.players.every((player) => player.score === 0));
});

test("host can lock a slow round, and a dropped host passes the button", () => {
  const game = setup();
  const ava = fakeWs();
  const noah = fakeWs();
  const mia = fakeWs();
  game.handle(ava, { type: "create", name: "Ava", rounds: 3 });
  game.handle(noah, { type: "join", code: "ROOM", name: "Noah" });
  game.handle(mia, { type: "join", code: "ROOM", name: "Mia" });
  game.handle(ava, { type: "start" });
  game.handle(ava, { type: "submit", text: "Because the router is shy." });
  game.handle(noah, { type: "submit", text: "The goldfish is streaming." });
  game.handle(ava, { type: "lock" });
  assert.equal(stateOf(mia).phase, "vote");
  assert.equal(stateOf(mia).yourAnswer, null);

  const noahAnswer = stateOf(noah).answers.find((answer) => answer.yours).id;
  game.handle(mia, { type: "vote", answerId: noahAnswer });
  game.handle(ava, { type: "lock" });
  const reveal = stateOf(noah);
  assert.equal(reveal.phase, "reveal");
  assert.equal(reveal.players.find((player) => player.name === "Noah").score, 1);

  game.handle(ava, { type: "leave" });
  const after = stateOf(noah);
  assert.equal(after.you.isHost || after.players.find((player) => player.name === "Noah").isHost, true);
  assert.equal(after.players.some((player) => player.name === "Ava"), false);
});

test("a phone can resume with its token and a bad token is turned away", () => {
  const game = setup();
  const ava = fakeWs();
  game.handle(ava, { type: "create", name: "Ava", rounds: 5 });
  const first = stateOf(ava);
  game.disconnect(ava);

  const returned = fakeWs();
  game.handle(returned, {
    type: "resume",
    code: "room",
    playerId: first.you.id,
    token: first.you.token,
  });
  assert.equal(stateOf(returned).you.name, "Ava");
  assert.equal(stateOf(returned).players[0].connected, true);

  const stranger = fakeWs();
  game.handle(stranger, {
    type: "resume",
    code: "ROOM",
    playerId: first.you.id,
    token: "NOPE",
  });
  assert.match(errorsOf(stranger).at(-1), /Couldn't rejoin/);
});

test("empty rooms are swept after everybody leaves", () => {
  let clock = 1_000;
  const game = setup({ now: () => clock });
  const ava = fakeWs();
  game.handle(ava, { type: "create", name: "Ava", rounds: 3 });
  game.disconnect(ava);
  assert.equal(game.roomCount(), 1);
  clock += 16 * 60 * 1000;
  game.sweep();
  assert.equal(game.roomCount(), 0);
});
