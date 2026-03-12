![Poster](assets/Poster.jpg)
# NeuralConnect — AI-driven narrative mystery (iOS)

NeuralConnect is an iOS SpriteKit narrative game set aboard a Mars-bound cyberpunk shuttle. You explore the ship, observe NPCs, listen to their conversations, and use **Neural Connect** to “hack” into what characters remember — then connect the clues.

The game blends:
- **2D exploration** (SpriteKit) with a tap-to-move shuttle map
- **AI-generated NPC dialogue** (on-device Apple Intelligence when available, or DeepSeek)
- **Persistent long-term memory** via **EverMemOS** (so NPCs can remember across sessions)

## Gameplay (User POV)

NeuralConnect is designed around short, repeatable loops:

- **Move**: Tap anywhere to move your character around the map.
- **Listen**: If 2+ NPCs are nearby in the same zone, you can trigger a conversation and tap through the dialogue.
- **Hack**: If exactly 1 NPC is nearby, you can Neural Connect to that NPC and view their memory logs.
- **Investigate**: Each hack updates your **clue board** (a lightweight knowledge graph) to help you connect entities, topics, and relationships.

The shuttle is split into 6 zones:
`Gym`, `Medbay`, `Lab`, `Power Room`, `Bar`, `Casino`.

## AI + Memory Backend

NeuralConnect uses two distinct “intelligence” layers:

### 1) Dialogue generation

NPC-to-NPC conversations are generated at runtime using one of:
- **DeepSeek** (recommended): enabled via API key in Settings
- **Apple FoundationModels** (on-device): used automatically when available on iOS 26+
- **Fallback**: a simple placeholder provider when no model is available

### 2) Persistent long-term memory (EverMemOS)

NPCs store conversation summaries and observations to **EverMemOS** so they can recall context later. This is not a per-session chat log — it’s long-term memory that accumulates.

Two deployment modes are supported:

**Local**
- Point the app at your local EverMemOS server (e.g. `http://localhost:1995` or `http://192.168.x.x:1995`)
- No token required

**Cloud**
- Point the app at your hosted EverMemOS endpoint
- Requires an auth token (stored in Keychain)

## Getting Started

### Requirements

- macOS with **Xcode 26+**
- iOS **26.0+** (device or Simulator)
- An EverMemOS backend (local or cloud) if you want persistent memory

### Build & Run (Xcode)

1. Open `NeuralConnect.xcodeproj` in Xcode
2. Select a destination (Simulator or a connected iPhone)
3. Build & Run

### Build from CLI (device)

```bash
xcodebuild -project NeuralConnect.xcodeproj \
  -scheme NeuralConnect \
  -configuration Debug \
  -sdk iphoneos26.2 \
  build
```

### Deploy scripts

This repo includes convenience scripts for fast device iteration:

```bash
./scripts/deploy_16pro.sh
./scripts/watch_deploy_16pro.sh
```

Scripts accept env overrides: `DEVICE_ID`, `SDK`, `CONFIGURATION`, `BUNDLE_ID`.

### Configuration (in-app)

Open **Settings** (gear icon) to configure:

- **EverMemOS**
  - Mode: Local / Cloud
  - Base URL
  - Token (Cloud only)
- **AI Dialogue Engine**
  - Enable/disable DeepSeek + API key
  - If DeepSeek is off/unconfigured, the app will try to use on-device Apple Intelligence when available
- **Language**
  - English / 中文
- **Data Management**
  - Delete all NPC memories (clears EverMemOS data and resets relationships)

## Packages

- `Packages/EverMemOSKit`: Swift SDK for EverMemOS (HTTP transport, SSE streaming, retries)
- `Packages/MemosKit`: thin app-level wrapper around EverMemOSKit

Run package tests:

```bash
cd Packages/EverMemOSKit && swift test
```

## Privacy & Data

NeuralConnect may send data to external services depending on how you configure it:

- **EverMemOS**: stores and retrieves NPC memory summaries/observations
- **DeepSeek** (optional): sends prompts for dialogue generation and summarization
- **Apple FoundationModels** (optional): runs on-device when supported

No external service is used until you configure credentials/URLs in Settings.

## Disclaimer

NeuralConnect is a research/creative prototype. It is not intended as a safety-critical system.

## License

No license file is provided in this repository. By default, all rights are reserved by the copyright holder.

