# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Deploy

```bash
# Build for device
xcodebuild -project NeuralConnect.xcodeproj -scheme NeuralConnect -configuration Debug -sdk iphoneos26.2 build

# Deploy to iPhone 16 Pro (builds, installs, launches)
./scripts/deploy_16pro.sh

# Watch mode: auto-deploy on file changes
./scripts/watch_deploy_16pro.sh

# EverMemOSKit package tests (51 tests)
cd Packages/EverMemOSKit && swift test
```

Deploy scripts accept env overrides: `DEVICE_ID`, `SDK`, `CONFIGURATION`, `BUNDLE_ID`.

## Architecture

**iOS SpriteKit game** (Swift, iOS 26.0+) — a cyberpunk narrative set on a Mars-bound shuttle with AI-driven NPC dialogue.

### Runtime Stack
- **SpriteKit** — 2D gameplay (GameScene with physics, camera, ship zones)
- **SwiftUI + UIKit** — hybrid UI; UIKit base with SwiftUI overlays for dialogue
- **Apple FoundationModels** — on-device LLM for NPC dialogue generation (iOS 26+)
- **EverMemOS** — external long-term memory API for conversational AI agents

### Key Layers

**AppShell** (`NeuralConnect/AppShell/`) — App lifecycle. `GameViewController` hosts the SpriteKit scene and manages the SwiftUI dialog overlay.

**Shuttle2D** (`NeuralConnect/Shuttle2D/`) — Game world. `GameScene` defines 6 ship zones (bar, ecology dome, observation deck, chapel, clinic, crew commons) with NPC placement, player movement, and proximity-based dialogue triggers.

**Dialog System** (`NeuralConnect/UI/Dialog/`) — Three-file MVC: `DialogModels` (DialogLine/DialogConversation types), `DialogViewModel` (Combine ObservableObject managing conversation state), `DialogOverlayView` (SwiftUI view with blur/darkening, speaker highlighting, tap-to-advance).

**AI Dialogue** (`NeuralConnect/AI/Dialogue/`) — Provider pattern: `DialogueProvider` protocol with `AppleFoundationModelsDialogueProvider` (on-device) and `FallbackDialogueProvider`. `DialogueService` orchestrates generation with prompt construction in Simplified Chinese.

**Packages** (`Packages/`) — Two local Swift packages:
- `EverMemOSKit` — Full SDK for EverMemOS memory API (auth, HTTP transport, SSE streaming, retry logic). Actor-based, zero dependencies.
- `MemosKit` — Thin actor-based wrapper around EverMemOSKit for app-level use.

**Modules** (`Modules/`) — Planned modular architecture (mostly scaffolding). Future expansion points for GameCore, Hack3D, DevTools, etc.

### Patterns
- Async/await with `@MainActor` for UI code, Swift actors for thread-safe services
- Delegation (`GameSceneDelegate`) for game-to-UI communication
- Provider protocol + fallback for swappable AI backends
- Builder pattern for EverMemOSKit queries (`SearchMemoriesBuilder`, `FetchMemoriesBuilder`)

## Dialogue Prompts

NPC dialogue prompts are constructed in **Simplified Chinese**. The system supports 2-character conversations with left/right speaker positioning.
