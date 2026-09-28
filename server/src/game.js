import { PROMPTS } from "./prompts.js";

export class GameError extends Error {
  constructor(message) {
    super(message);
    this.name = "GameError";
  }
}

const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ";
const NAME_RE = /^[\p{L}\p{N}][\p{L}\p{N} '’\-]{0,15}$/u;
const MIN_PLAYERS = 2;
const MAX_PLAYERS = 8;
const IDLE_MS = 15 * 60 * 1000;

export function shuffle(list, rng = Math.random) {
  const copy = [...list];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(rng() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function randomToken(rng) {
  let token = "";
  for (let i = 0; i < 24; i += 1) {
    token += CODE_ALPHABET[Math.floor(rng() * CODE_ALPHABET.length)];
  }
  return token;
}

function randomId(prefix, rng) {
  return `${prefix}${randomToken(rng).slice(0, 10)}`;
}

function makeCode(existing, rng) {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    let code = "";
    for (let i = 0; i < 4; i += 1) {
      code += CODE_ALPHABET[Math.floor(rng() * CODE_ALPHABET.length)];
    }
    if (!existing.has(code)) return code;
  }
  throw new GameError("Every room code is taken. Try again in a minute.");
}

export function cleanName(name) {
  if (typeof name !== "string") throw new GameError("Enter a name.");
  const trimmed = name.trim().replace(/\s+/g, " ");
  if (!NAME_RE.test(trimmed)) {
    throw new GameError("Use 1–16 letters or numbers for your name.");
  }
  return trimmed;
}

export function cleanAnswer(text) {
  if (typeof text !== "string") throw new GameError("Write an answer first.");
  const trimmed = text.trim().replace(/\s+/g, " ");
  if (trimmed.length < 1 || trimmed.length > 140) {
    throw new GameError("Answers need 1–140 characters.");
  }
  return trimmed;
}

export function cleanRounds(rounds) {
  const value = Number(rounds ?? 5);
  if (![3, 5, 7].includes(value)) {
    throw new GameError("Pick 3, 5, or 7 rounds.");
  }
  return value;
}

export function normalizeCode(code) {
  if (typeof code !== "string") throw new GameError("Enter a room code.");
  return code.trim().toUpperCase().replace(/[^A-Z]/g, "");
}

function connectedPlayers(room) {
  return [...room.players.values()].filter((player) => player.connected);
}

function activeRoundPlayers(room) {
  return room.roundPlayerIds
    .map((id) => room.players.get(id))
    .filter((player) => player && player.connected);
}

function canVote(room, player) {
  return room.answers.some((answer) => answer.authorId !== player.id);
}

function freshDeck(prompts, rng) {
  const deck = shuffle(prompts, rng);
  if (deck.length < 3) {
    throw new GameError("The prompt deck needs at least 3 prompts.");
  }
  return deck;
}

function publicAnswer(answer, player, reveal) {
  return {
    id: answer.id,
    text: answer.text,
    yours: answer.authorId === player.id,
    authorName: reveal ? answer.authorName : null,
    votes: reveal ? answer.votes.length : 0,
  };
}

function snapshot(room, player) {
  const reveal = room.phase === "reveal" || room.phase === "final";
  const showAnswers = room.phase === "vote" || room.phase === "reveal";
  const yourAnswer = room.answers.find((answer) => answer.authorId === player.id);
  const players = [...room.players.values()];
  const ordered =
    room.phase === "reveal" || room.phase === "final"
      ? [...players].sort(
          (a, b) => b.score - a.score || a.name.localeCompare(b.name),
        )
      : players;

  return {
    code: room.code,
    phase: room.phase,
    round: room.round,
    totalRounds: room.totalRounds,
    prompt: room.prompt,
    you: {
      id: player.id,
      token: player.token,
      name: player.name,
      isHost: room.hostId === player.id,
      score: player.score,
    },
    players: ordered.map((entry) => ({
      id: entry.id,
      name: entry.name,
      score: entry.score,
      connected: entry.connected,
      isHost: entry.id === room.hostId,
      submitted: entry.submitted,
      voted: Boolean(entry.voteAnswerId),
    })),
    answers: showAnswers
      ? room.answers.map((answer) => publicAnswer(answer, player, reveal))
      : [],
    yourAnswer: yourAnswer ? yourAnswer.text : null,
    yourVote: player.voteAnswerId,
    submittedCount: room.answers.length,
    voterCount: room.answers.reduce(
      (sum, answer) => sum + (reveal ? answer.votes.length : 0),
      0,
    ),
  };
}

export function createGame({
  prompts = PROMPTS,
  rng = Math.random,
  now = () => Date.now(),
  codeFactory,
} = {}) {
  const rooms = new Map();
  const sockets = new Map();

  function send(ws, message) {
    if (!ws || ws.readyState !== 1 || typeof ws.send !== "function") return;
    ws.send(JSON.stringify(message));
  }

  function broadcast(room) {
    for (const player of room.players.values()) {
      if (!player.ws) continue;
      send(player.ws, { type: "state", room: snapshot(room, player) });
    }
  }

  function fail(ws, error) {
    const message = error instanceof Error ? error.message : "Something went wrong.";
    send(ws, { type: "error", message });
  }

  function binding(ws) {
    return sockets.get(ws) ?? null;
  }

  function requireBinding(ws) {
    const current = binding(ws);
    if (!current) throw new GameError("Join a room first.");
    const room = rooms.get(current.code);
    const player = room?.players.get(current.playerId);
    if (!room || !player) throw new GameError("That room closed.");
    return { room, player };
  }

  function attach(ws, room, player) {
    const previous = player.ws;
    if (previous && previous !== ws) {
      sockets.delete(previous);
      previous.replaced = true;
      try {
        previous.close?.();
      } catch {
        // The old phone already went away.
      }
    }
    player.ws = ws;
    player.connected = true;
    room.idleSince = null;
    sockets.set(ws, { code: room.code, playerId: player.id });
  }

  function transferHost(room) {
    if (room.players.get(room.hostId)?.connected) return;
    const next = connectedPlayers(room)[0];
    if (next) room.hostId = next.id;
  }

  function maybeAdvance(room) {
    if (room.phase === "submit") {
      const active = activeRoundPlayers(room);
      if (
        active.length >= MIN_PLAYERS &&
        active.every((player) => player.submitted) &&
        room.answers.length >= MIN_PLAYERS
      ) {
        beginVote(room);
      }
      return;
    }
    if (room.phase === "vote") {
      const eligible = activeRoundPlayers(room).filter((player) => canVote(room, player));
      if (eligible.length > 0 && eligible.every((player) => player.voteAnswerId)) {
        awardAndReveal(room);
      }
    }
  }

  function beginVote(room) {
    room.answers = shuffle(room.answers, rng);
    room.phase = "vote";
  }

  function awardAndReveal(room) {
    if (room.phase === "reveal" || room.phase === "final") return;
    for (const answer of room.answers) {
      const author = room.players.get(answer.authorId);
      if (author) author.score += answer.votes.length;
    }
    room.phase = "reveal";
  }

  function startRound(room) {
    if (room.promptIndex >= room.promptDeck.length) {
      room.promptDeck = freshDeck(prompts, rng);
      room.promptIndex = 0;
    }
    room.prompt = room.promptDeck[room.promptIndex];
    room.promptIndex += 1;
    room.round += 1;
    room.phase = "submit";
    room.answers = [];
    room.roundPlayerIds = connectedPlayers(room).map((player) => player.id);
    for (const player of room.players.values()) {
      player.submitted = false;
      player.voteAnswerId = null;
    }
  }

  function assertHost(room, player) {
    if (room.hostId !== player.id) {
      throw new GameError("Only the host can do that.");
    }
  }

  function createRoom(ws, msg) {
    if (binding(ws)) throw new GameError("You're already in a room.");
    const name = cleanName(msg.name);
    const totalRounds = cleanRounds(msg.rounds);
    const code = codeFactory ? codeFactory(rooms) : makeCode(rooms, rng);
    const player = {
      id: randomId("p", rng),
      token: randomToken(rng),
      name,
      score: 0,
      connected: true,
      submitted: false,
      voteAnswerId: null,
      ws: null,
    };
    const room = {
      code,
      hostId: player.id,
      phase: "lobby",
      round: 0,
      totalRounds,
      prompt: null,
      promptDeck: freshDeck(prompts, rng),
      promptIndex: 0,
      players: new Map([[player.id, player]]),
      answers: [],
      roundPlayerIds: [],
      idleSince: null,
      createdAt: now(),
    };
    rooms.set(code, room);
    attach(ws, room, player);
    broadcast(room);
  }

  function joinRoom(ws, msg) {
    if (binding(ws)) throw new GameError("You're already in a room.");
    const code = normalizeCode(msg.code);
    const room = rooms.get(code);
    if (!room) throw new GameError("No room with that code.");
    if (room.phase !== "lobby") {
      throw new GameError("That game already started. Wait for the next one.");
    }
    if (room.players.size >= MAX_PLAYERS) {
      throw new GameError("This room is full (8 players).");
    }
    const name = cleanName(msg.name);
    const taken = [...room.players.values()].some(
      (player) => player.name.toLowerCase() === name.toLowerCase(),
    );
    if (taken) throw new GameError("Somebody in the room already has that name.");
    const player = {
      id: randomId("p", rng),
      token: randomToken(rng),
      name,
      score: 0,
      connected: true,
      submitted: false,
      voteAnswerId: null,
      ws: null,
    };
    room.players.set(player.id, player);
    attach(ws, room, player);
    broadcast(room);
  }

  function resume(ws, msg) {
    const code = normalizeCode(msg.code);
    const room = rooms.get(code);
    const player = room?.players.get(msg.playerId);
    if (!room || !player || player.token !== msg.token) {
      throw new GameError("Couldn't rejoin that room. Hop back in with the code.");
    }
    attach(ws, room, player);
    transferHost(room);
    maybeAdvance(room);
    broadcast(room);
  }

  function startGame(ws) {
    const { room, player } = requireBinding(ws);
    assertHost(room, player);
    if (room.phase !== "lobby") throw new GameError("The game already started.");
    const count = connectedPlayers(room).length;
    if (count < MIN_PLAYERS) {
      throw new GameError("Need at least 2 players. Three or more is the sweet spot.");
    }
    if (count > MAX_PLAYERS) throw new GameError("This room is full (8 players).");
    room.round = 0;
    startRound(room);
    broadcast(room);
  }

  function submit(ws, msg) {
    const { room, player } = requireBinding(ws);
    if (room.phase !== "submit") throw new GameError("Answers are closed.");
    if (!room.roundPlayerIds.includes(player.id)) {
      throw new GameError("You missed the start of this round.");
    }
    const text = cleanAnswer(msg.text);
    const existing = room.answers.find((answer) => answer.authorId === player.id);
    if (existing) {
      existing.text = text;
    } else {
      room.answers.push({
        id: randomId("a", rng),
        authorId: player.id,
        authorName: player.name,
        text,
        votes: [],
      });
    }
    player.submitted = true;
    maybeAdvance(room);
    broadcast(room);
  }

  function vote(ws, msg) {
    const { room, player } = requireBinding(ws);
    if (room.phase !== "vote") throw new GameError("Voting isn't open.");
    const answer = room.answers.find((entry) => entry.id === msg.answerId);
    if (!answer) throw new GameError("That answer isn't in this round.");
    if (answer.authorId === player.id) {
      throw new GameError("You can't vote for your own answer.");
    }
    for (const entry of room.answers) {
      entry.votes = entry.votes.filter((id) => id !== player.id);
    }
    answer.votes.push(player.id);
    player.voteAnswerId = answer.id;
    maybeAdvance(room);
    broadcast(room);
  }

  function lock(ws) {
    const { room, player } = requireBinding(ws);
    assertHost(room, player);
    if (room.phase === "submit") {
      if (room.answers.length < MIN_PLAYERS) {
        throw new GameError("Need at least 2 answers before voting.");
      }
      beginVote(room);
      broadcast(room);
      return;
    }
    if (room.phase === "vote") {
      awardAndReveal(room);
      broadcast(room);
      return;
    }
    throw new GameError("Nothing to lock right now.");
  }

  function next(ws) {
    const { room, player } = requireBinding(ws);
    assertHost(room, player);
    if (room.phase !== "reveal") throw new GameError("Finish the round first.");
    if (room.round >= room.totalRounds) {
      room.phase = "final";
      room.prompt = null;
    } else {
      startRound(room);
    }
    broadcast(room);
  }

  function again(ws) {
    const { room, player } = requireBinding(ws);
    assertHost(room, player);
    if (room.phase !== "final") throw new GameError("Finish this game first.");
    room.phase = "lobby";
    room.round = 0;
    room.prompt = null;
    room.answers = [];
    room.roundPlayerIds = [];
    room.promptDeck = freshDeck(prompts, rng);
    room.promptIndex = 0;
    for (const entry of room.players.values()) {
      entry.score = 0;
      entry.submitted = false;
      entry.voteAnswerId = null;
    }
    broadcast(room);
  }

  function leave(ws) {
    const current = binding(ws);
    if (!current) return;
    const room = rooms.get(current.code);
    sockets.delete(ws);
    if (!room) return;
    const player = room.players.get(current.playerId);
    if (player?.ws === ws) {
      room.players.delete(player.id);
    }
    if (room.players.size === 0) {
      rooms.delete(room.code);
      return;
    }
    room.roundPlayerIds = room.roundPlayerIds.filter((id) => room.players.has(id));
    room.answers = room.answers.filter((answer) => room.players.has(answer.authorId));
    for (const answer of room.answers) {
      answer.votes = answer.votes.filter((id) => room.players.has(id));
    }
    transferHost(room);
    maybeAdvance(room);
    broadcast(room);
  }

  function handle(ws, msg) {
    if (!msg || typeof msg !== "object" || typeof msg.type !== "string") {
      throw new GameError("That message didn't make sense.");
    }
    switch (msg.type) {
      case "ping":
        send(ws, { type: "pong" });
        return;
      case "create":
        createRoom(ws, msg);
        return;
      case "join":
        joinRoom(ws, msg);
        return;
      case "resume":
        resume(ws, msg);
        return;
      case "start":
        startGame(ws);
        return;
      case "submit":
        submit(ws, msg);
        return;
      case "vote":
        vote(ws, msg);
        return;
      case "lock":
        lock(ws);
        return;
      case "next":
        next(ws);
        return;
      case "again":
        again(ws);
        return;
      case "leave":
        leave(ws);
        return;
      default:
        throw new GameError("Unknown action.");
    }
  }

  function disconnect(ws) {
    const current = sockets.get(ws);
    if (!current) return;
    sockets.delete(ws);
    const room = rooms.get(current.code);
    const player = room?.players.get(current.playerId);
    if (!room || !player || player.ws !== ws) return;
    player.ws = null;
    player.connected = false;
    transferHost(room);
    if (connectedPlayers(room).length === 0) {
      room.idleSince = now();
    }
    maybeAdvance(room);
    broadcast(room);
  }

  function sweep(maxIdleMs = IDLE_MS) {
    const cutoff = now() - maxIdleMs;
    for (const [code, room] of rooms) {
      if (room.idleSince != null && room.idleSince <= cutoff) {
        rooms.delete(code);
      }
    }
  }

  return {
    handle(ws, msg) {
      try {
        handle(ws, msg);
      } catch (error) {
        fail(ws, error);
      }
    },
    disconnect,
    sweep,
    roomCount: () => rooms.size,
    getRoom: (code) => rooms.get(code) ?? null,
  };
}
