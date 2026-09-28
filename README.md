# Worst Answer Wins

A funny family party game in the Jackbox style. Somebody hosts a room, everyone else joins with a short code, and each round asks a silly question. Players write a fake answer, vote for the funniest one (not their own), and the votes become points. The worst answer wins.

No accounts. Built for phones: a Flutter app (Android APK and web) plus a small Node realtime server. The starter deck has 40 PG prompts.

## Run it locally

You need Node.js 22+ and Flutter 3.47 or newer (stable channel). The app's language version matches that SDK.

### Server

```bash
cd server
npm install
npm start
```

The server listens on port 8787.

- Health check: [http://localhost:8787/health](http://localhost:8787/health)
- Rooms are in memory. Restarting the server clears them.

```bash
npm test
```

### App

```bash
cd app
flutter pub get
flutter run -d chrome
```

To open the web app from other devices on your Wi-Fi:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Then visit `http://YOUR-LAN-IP:8080`. The app defaults the server to `ws://` that same host on port 8787.

On the Android emulator:

```bash
flutter run
```

The emulator default is `ws://10.0.2.2:8787`, which is your computer's localhost.

```bash
cd app
flutter test
```

## Build the Android debug APK

From `app/`, with the Flutter SDK and Android SDK installed:

```bash
flutter pub get
flutter build apk --debug
```

The APK is written to:

```text
app/build/app/outputs/flutter-apk/app-debug.apk
```

Install it on a phone with USB debugging:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Run that `adb` command from the `app` directory. Debug builds are signed with the debug key, which is what you want for a living-room demo. The app allows cleartext `ws://` so phones can reach a server on your LAN. For a public party, put the server behind `wss://` and type that address in the app.

### GitHub Actions

[`.github/workflows/android-debug-apk.yml`](.github/workflows/android-debug-apk.yml) runs the server tests, `flutter analyze`, `flutter test`, and `flutter build apk --debug` on every pull request and on pushes to `main`. Download the artifact named **worst-answer-wins-debug-apk**.

## Play a round with 2 phones

Three to eight players is the full party. Two is enough to play a round tonight.

1. Put the computer and both phones on the same Wi-Fi.
2. Start the server with `npm start` inside `server/`.
3. Find the computer's LAN address.
   - Linux: `hostname -I`
   - macOS: `ipconfig getifaddr en0`
4. Install the debug APK on both phones. A computer browser can stand in for one of them.
5. In the app, set **Server** to `ws://192.168.x.x:8787` using that address. Allow port 8787 through the computer's firewall if the phones cannot connect.
6. Phone A taps **Host a party**, enters a name, picks **3** rounds, and taps **Open the room**.
7. Phone B taps **Join with a code**, enters the 4 letters and a different name.
8. The host taps **Start the nonsense**.
9. Both players write an answer and tap **Send it**. Voting opens when every answer is in. If someone is stuck, the host can tap **Lock answers** once two answers exist.
10. Each player taps the other answer. Your own answer is marked and cannot be selected.
11. The reveal shows who wrote what and adds a point per vote. The host taps **Next round**.
12. After the third reveal, the host taps **Show the winner**.

Answers stay anonymous until voting closes. Then the authors and the scoreboard show up. The host can tap **Play again** to return to the lobby with scores reset.

## How a round works

1. **Lobby.** The host shares the code. The game starts with 2–8 connected players.
2. **Submit.** Everyone sees the same prompt and writes up to 140 characters. You can update the answer until voting starts.
3. **Vote.** Answer order is shuffled. You cannot vote for yourself. You can change your vote until everyone has voted.
4. **Reveal.** One point per vote. The host advances.
5. **Final.** Highest score wins. Ties share the crown.

Choose 3, 5, or 7 rounds when you host. The deck has 40 family-friendly prompts and will not repeat inside a game until it wraps.

The prompts are PG. Players type their own answers, so a grown-up should be the host.
