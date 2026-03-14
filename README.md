<p align="center">
  <img width="120" src="assets/logo.png" alt="NeuralConnect logo" style="border-radius: 20px;">
</p>

<h1 align="center">NeuralConnect</h1>

<p align="center">
  A Memory-Driven Multi-Agent NPC Experience Powered by <a href="https://github.com/EverMind-AI/EverMemOS">EverMemOS</a>.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2026-2f7af8" alt="platform">
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift">
  <img src="https://img.shields.io/badge/SpriteKit-2D-cyan" alt="SpriteKit">
</p>

<p align="center">
  An iOS narrative mystery set aboard a Mars-bound cyberpunk shuttle, where you explore the ship, listen in on NPC conversations, and use Neural Connect to dive into what characters remember, connect the clues, and uncover the truth.
</p>

<p align="center">
  <strong>🚀 <a href="https://testflight.apple.com/join/KgeybCZp">Join TestFlight Beta</a></strong>
</p>

---

![Poster](assets/Poster.jpg)

## Demo Video
https://youtu.be/6jui5UAV2CI

## Characters

<table>
<tr>
<td width="33%" align="center">
<img src="assets/Profile_Yangman.jpeg" width="200"><br>
<strong>The Stowaway</strong><br>
<em>Odd-jobs Hand</em><br>
Underground hacking legend 'Phantom' — breached a military firewall at age 14. Wants to survive to Mars and start over, but can't resist probing the ship's system vulnerabilities.
</td>
<td width="33%" align="center">
<img src="assets/Profile_AI.png" width="200"><br>
<strong>AI Android</strong><br>
<em>Navigation Assistant</em><br>
Has deduced every passenger's secret, but ethics protocols forbid proactive disclosure. Searching for a legitimate way to get the truth out.
</td>
<td width="33%" align="center">
<img src="assets/Profile_Waiter.png" width="200"><br>
<strong>Attendant</strong><br>
<em>Flight Attendant</em><br>
An AI psychotherapist — a profession that officially doesn't exist. Evaluating Android's psychological state, but the deeper she digs, the more she realizes it's actively asking for help.
</td>
</tr>
<tr>
<td width="33%" align="center">
<img src="assets/Profile_GemGuy.png" width="200"><br>
<strong>Gym Guy</strong><br>
<em>Regular Passenger</em><br>
The most famous sci-fi author in the solar system, traveling under a false name to escape to Mars. Fame killed his writing; wants to recapture the quiet of his hydroelectric station days.
</td>
<td width="33%" align="center">
<img src="assets/Profile_Doctor.jpg" width="200"><br>
<strong>Doctor</strong><br>
<em>Ship Doctor / Cybernetic Surgeon</em><br>
Clinically died three years ago, revived by replacing organs and neural tissue with bio-synthetic parts — half human, half machine. Secretly collecting medical data from passengers to refine the immortality procedure.
</td>
<td width="33%" align="center">
<img src="assets/Profile_Captain.png" width="200"><br>
<strong>Captain</strong><br>
<em>Acting Captain</em><br>
The stowaway kid is his biological son; volunteered for captain specifically to protect him. Trying to keep his son's identity hidden and survive the six-month voyage safely to Mars.
</td>
</tr>
</table>

## What players do

NeuralConnect is built around a simple loop:

- **Explore** a 2D shuttle map (tap to move).
- **Listen** when multiple NPCs are nearby.
- **Connect** to a single NPC to review their memory trail.
- **Investigate** with a visual clue board that grows as you learn more.

The ship is divided into six zones: `Gym`, `Medbay`, `Lab`, `Power Room`, `Bar`, `Casino`.

## Key features

- **AI-driven dialogue** between NPCs (with fallback when AI is unavailable)
- **Persistent character memory** so NPCs can build context over time
- **Clue board / knowledge graph** that helps you spot relationships and recurring topics
- **English / 中文** support

## Emergent NPC dialogue samples

Full simulation logs — 30 AI-generated conversations where NPCs build memories, form relationships, and reveal secrets over time:

- [English](docs/simulation_log_v3.md) | [中文](docs/simulation_log_v3.zh.md)

## Modes & settings (in-app)

From the gear icon you can:

- Switch **Language** (English / 中文)
- Choose the **AI dialogue engine** (optional)
- Configure the **memory backend** (optional)
- **Delete all NPC memories** (for a clean playthrough / testing)
- Replay the intro story sequence

## Getting started (dev)

### Requirements

- Xcode 26+
- iOS 26+ (Simulator or device)
- EverMemOS backend (required to start gameplay)
  - Cloud: base URL + token
  - Local: base URL (no token)
- AI dialogue provider (optional)
  - DeepSeek API key (recommended), or
  - Apple Intelligence on-device (when available on iOS 26+)

### Run

1. Open `NeuralConnect.xcodeproj`
2. Select a destination
3. Build & Run

### First-run setup (in-app)

The game won’t start until EverMemOS is configured:

1. Open **Settings** (gear icon)
2. Configure **EverMemOS**
   - **Cloud**: enter Base URL + Token
   - **Local**: enter Base URL (tip: on iPhone, don’t use `localhost` — use a reachable LAN IP)
3. (Optional) Configure **AI Dialogue Engine**
   - Enable DeepSeek and enter an API key, or rely on Apple Intelligence if available on your device

## Privacy / data

NeuralConnect can be run in a “local-only / offline” style depending on what you enable in Settings.

If you opt in to external services, the app may send:
- NPC memory summaries/metadata to the configured memory backend
- Dialogue generation requests to the configured AI provider

Nothing is sent until you enter credentials/URLs in Settings.

Full privacy policy: [docs/privacy-policy.md](docs/privacy-policy.md)

## Disclaimer

NeuralConnect is a creative/research prototype and is not intended for safety-critical use.

## License

No license file is provided in this repository. By default, all rights are reserved by the copyright holder.
