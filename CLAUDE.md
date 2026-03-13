# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Deploy

```bash
# Build for device
xcodebuild -project NeuralConnect.xcodeproj -scheme NeuralConnect -configuration Debug -sdk iphoneos26.2 build

# Deploy to iPhone 16 Pro (builds, installs, launches)
./scripts/deploy_16pro.sh

# Watch mode: auto-deploy on file changes (watches *.swift, *.plist, *.sks, *.json, etc.)
./scripts/watch_deploy_16pro.sh

# Run app tests
xcodebuild -project NeuralConnect.xcodeproj -scheme NeuralConnect test -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Deploy scripts accept env overrides: `DEVICE_ID`, `SDK`, `CONFIGURATION`, `BUNDLE_ID`, `DERIVED_DATA_PATH`.

## Architecture

**iOS SpriteKit game** (Swift, iOS 26.0+) — a cyberpunk narrative set on a Mars-bound shuttle with AI-driven NPC dialogue. Players explore ship zones, witness AI-generated NPC conversations, and can "brain hack" NPCs to read/write memory layers.

### Runtime Stack
- **SpriteKit** — 2D gameplay (GameScene with physics, camera, ship zones)
- **SwiftUI + UIKit** — hybrid UI; UIKit base with SwiftUI overlays for dialogue
- **Apple FoundationModels** — on-device LLM for NPC dialogue generation (iOS 26+)
- **DeepSeek API** — cloud-based Chinese LLM as primary dialogue provider
- **EverMemOS** — external long-term memory API for NPC cognitive state

### Key Layers

**AppShell** (`NeuralConnect/AppShell/`) — App lifecycle. `GameViewController` hosts the SpriteKit scene and manages the SwiftUI dialog overlay.

**Shuttle2D** (`NeuralConnect/Shuttle2D/`) — Game world. `GameScene` defines 6 ship zones with NPC placement, player movement, and proximity-based dialogue triggers.

**Zone Scheduling** (`NeuralConnect/Models/ZoneScheduling/`) — Core game loop. `ZoneScheduler` places NPCs into zones and selects conversation pairs. `PairScorer` uses relationship-weighted scoring. Zone dwell tracking (2s threshold) prevents accidental re-triggers. The 6 zones: `gym`, `hospital`, `lab`, `energy`, `bar`, `casino`.

**Cognitive System** (`NeuralConnect/AI/Cognitive/`) — NPC intelligence layer:
- `NPCBrain` (actor) — per-NPC state: memories, foresights, recent phrases, partner relationships
- `NPCBrainManager` — orchestrates multiple brains, handles memory recall, foresight predictions, relationship scoring
- `MemoryStore` (actor) — wraps EverMemOS API for fetching/searching memories with fallback caching
- `ConversationIntent` / `ConversationOutcome` — enum-based conversation classification
- `SecretScorer` — rates how close conversations get to NPC secrets
- `PromptBuilder` — constructs full conversation prompts with memory context, character bios, relationship state

**Dialog System** (`NeuralConnect/UI/Dialog/`) — Three-file MVC: `DialogModels` (DialogLine/DialogConversation types), `DialogViewModel` (Combine ObservableObject managing conversation state), `DialogOverlayView` (SwiftUI view with blur/darkening, speaker highlighting, tap-to-advance).

**AI Dialogue** (`NeuralConnect/AI/Dialogue/`) — Three providers with fallback chain: `DeepSeekDialogueProvider` (tried first if configured) → `AppleFoundationModelsDialogueProvider` (on-device) → `FallbackDialogueProvider` (static lines). `DialogueService` orchestrates generation. Multi-stage pipeline: intent detection → memory recall → prompt construction → LLM generation → post-processing → memory storage.

**Configuration** (`NeuralConnect/AI/Config/`) — `EverMemOSConfig` supports dual-mode deployment (cloud/local) with separate base URLs. `DeepSeekConfig` manages API tokens. `KeychainHelper` handles secure token storage with automatic migration from UserDefaults.

**Debug Tools** (`NeuralConnect/Debug/`) — `DebugAutoPlay` runs headless auto-ticking (up to 80 ticks) of zone scheduling with real AI conversations and memory storage, logging to file. Only active in DEBUG configuration. Useful for testing emergent narrative behavior.

**Packages** (`Packages/`) — `MemosKit` is a thin actor-based wrapper around `EverMemOSKit` (remote dependency, v0.1.0+) for app-level memory operations.

**Modules** (`Modules/`) — Planned modular architecture (mostly scaffolding). Future expansion points for GameCore, Hack3D, DevTools, etc.

### Patterns
- Async/await with `@MainActor` for UI code, Swift actors for thread-safe services
- Delegation (`GameSceneDelegate`) for game-to-UI communication
- Provider protocol + fallback chain for swappable AI backends
- Builder pattern for EverMemOSKit queries (`SearchMemoriesBuilder`, `FetchMemoriesBuilder`)
- `L()` helper for bilingual Chinese/English localization via `GameLanguage` enum

## Dialogue Prompts

NPC dialogue prompts are constructed in **Simplified Chinese**. The system supports 2-character conversations with left/right speaker positioning. DeepSeek prompts include extensive (167-line) system instructions with dialogue quality rules.
