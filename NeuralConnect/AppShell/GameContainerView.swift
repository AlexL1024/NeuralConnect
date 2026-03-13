import SwiftUI
import SpriteKit
import Combine
import os.log
import EverMemOSKit

struct GameContainerView: View {
    var onReplayIntro: (() -> Void)?
    @StateObject private var dialogViewModel = DialogViewModel()
    @StateObject private var gameState = GameState()

    @State private var gameScene: GameScene = {
        let scene = GameScene(size: CGSize(width: 1024, height: 768))
        scene.scaleMode = .aspectFill
        return scene
    }()

    @State private var npcBrainManager: NPCBrainManager?
    @State private var dialogueService: DialogueService?
    @State private var showSettings = false
    @State private var hackTargetNPCId: String?
    @State private var hackTargetName: String?
    @State private var didSetup = false
    @State private var showConfigAlert = false
    @State private var playerInvestigation: [String: [TimestampedMemory]] = [:]
    #if DEBUG
    @State private var debugAutoPlay: DebugAutoPlay?
    #endif

    private var bridge: GameSceneBridge { gameScene.bridge }

    var body: some View {
        ZStack {
            SpriteView(scene: gameScene)
                .ignoresSafeArea()

            DialogOverlayView(viewModel: dialogViewModel)

            if let npcId = hackTargetNPCId, let name = hackTargetName {
                HackOverlayView(
                    npcId: npcId,
                    npcName: name,
                    playerInvestigation: $playerInvestigation,
                    hackAction: {
                        guard let bm = npcBrainManager else { return nil }
                        return await bm.hackNPC(npcId)
                    },
                    fetchConversationMetaAction: { groupId in
                        guard let bm = npcBrainManager else { return nil }
                        return await bm.conversationMeta(groupId: groupId)
                    },
                    onDismiss: {
                        hackTargetNPCId = nil
                        hackTargetName = nil
                        gameScene.setDialogActive(false)

                        if let bm = npcBrainManager {
                            bm.rescheduleNPCs(roster: NPCRoster.all, involvedNPCIds: Set([npcId]))
                            gameScene.updateNPCPositions(bm.currentZoneAssignments())
                            gameScene.applyCooldownVisuals(gameState.zoneState.cooldownNPCIds)
                        }
                    }
                )
            }

            // HUD overlay — hidden during hack and dialog
            if hackTargetNPCId == nil && !dialogViewModel.isVisible {
                VStack {
                    HStack(alignment: .top) {
                        // Settings & debug buttons (top-left)
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundStyle(.cyan)
                                .padding(12)
                        }
                        .padding(.leading, 16)

                        #if DEBUG
                        Button {
                            if debugAutoPlay != nil {
                                debugAutoPlay?.stop()
                                debugAutoPlay = nil
                            } else if let bm = npcBrainManager {
                                let ap = DebugAutoPlay(
                                    gameState: gameState,
                                    roster: NPCRoster.all,
                                    brainManager: bm,
                                    maxTicks: 120
                                )
                                debugAutoPlay = ap
                                ap.start(interval: 3.0)
                            }
                        } label: {
                            Image(systemName: debugAutoPlay != nil ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(debugAutoPlay != nil ? .red : .green)
                                .padding(12)
                        }
                        #endif

                        Spacer()

                        // Mini map (top-right) — hidden during dialog
                        if !dialogViewModel.isVisible {
                            MiniMapView(gameState: gameState, playerNormalizedPosition: bridge.playerNormalizedPosition)
                                .padding(.trailing, 16)
                        }
                    }
                    // Zone name overlay — always centered regardless of other elements
                    .overlay(alignment: .top) {
                        if let zoneName = bridge.currentZoneName {
                            StrokedText(text: zoneName.uppercased(), fontSize: 28, fillColor: .cyan, strokeColor: .black, strokeWidth: 3)
                                .padding(.top, 14)
                        }
                    }
                    .padding(.top, 8)
                    Spacer()
                }
            }

            // Tap-to-move hint — shown until first tap
            if !bridge.playerDidMove {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.title2)
                            .symbolEffect(.pulse)
                        Text(L("Tap anywhere to move", "点击屏幕移动"))
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.black.opacity(0.4)))
                    .padding(.bottom, 60)
                }
                .transition(.opacity)
                .animation(.easeOut(duration: 0.5), value: bridge.playerDidMove)
                .allowsHitTesting(false)
            }

            // Action buttons (bottom-center, pinned to edge)
            VStack {
                Spacer()

                // Listen button — when 2+ NPCs nearby
                if let conv = bridge.pendingConversation {
                    Button {
                        gameScene.triggerPendingConversation()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.title3)
                                .symbolEffect(.pulse)
                            Text("\(conv.left.displayName) & \(conv.right.displayName)")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .buttonStyle(.capsuleOutlined(color: .orange))
                    .padding(.bottom, 8)
                }

                // Hack button — when 1 NPC nearby
                if let npcId = bridge.hackableNPCId, let name = bridge.hackableNPCName {
                    Button {
                        hackTargetNPCId = npcId
                        hackTargetName = name
                        gameScene.setDialogActive(true)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "brain.head.profile")
                                .font(.title3)
                                .symbolEffect(.pulse)
                            Text("NEURAL CONNECT \(name)")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .buttonStyle(.capsuleOutlined)
                    .padding(.bottom, 8)
                }
            }
            .padding(.bottom, 12)
        }
        .onAppear {
            guard !didSetup else { return }
            didSetup = true
            setupSystem()

            #if DEBUG && targetEnvironment(simulator)
            // Auto-start auto-play in simulator for debugging
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if debugAutoPlay == nil, let bm = npcBrainManager {
                    let ap = DebugAutoPlay(
                        gameState: gameState,
                        roster: NPCRoster.all,
                        brainManager: bm,
                        maxTicks: 300,
                        maxConversations: 30,
                        cleanStart: true
                    )
                    debugAutoPlay = ap
                    ap.start(interval: 3.0)
                }
            }
            #endif
        }
        .onReceive(bridge.proximityEvent) { group in
            dialogueService?.startConversation(
                group: group,
                viewModel: dialogViewModel
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onSave: {
                setupSystem()
            }, onReplayIntro: onReplayIntro)
        }
        .alert(L("EverMemOS Setup Required", "需要配置 EverMemOS"), isPresented: $showConfigAlert) {
            Button(L("Open Settings", "打开设置")) {
                showSettings = true
            }
        } message: {
            Text(L("Please configure the EverMemOS Token and URL in Settings before starting the game.", "请先在设置中配置 EverMemOS 的 Token 和 URL 才能开始游戏。"))
        }
    }

    private func setupSystem() {
        EverMemOSConfig.migrateIfNeeded()

        let roster = NPCRoster.all

        gameScene.gameState = gameState

        #if targetEnvironment(simulator)
        let shouldSetup = true
        #else
        let shouldSetup = EverMemOSConfig.isConfigured
        #endif
        if shouldSetup, let memosService = EverMemOSConfig.buildService() {
            NHLogger.system.info("[System] EverMemOS \(EverMemOSConfig.deploymentMode.rawValue) mode, baseURL=\(EverMemOSConfig.baseURL.absoluteString)")
            let memoryStore = MemoryStore(service: memosService)
            let brainManager = NPCBrainManager(gameState: gameState, memoryStore: memoryStore)

            self.npcBrainManager = brainManager
            self.dialogueService = DialogueService(brainManager: brainManager)

            Task {
                await brainManager.initialize(roster: roster)
                let assignments = brainManager.currentZoneAssignments()
                NHLogger.system.info("[System] Initial zone assignments: \(assignments)")
                gameScene.updateNPCPositions(assignments)
            }

        } else {
            NHLogger.system.info("[System] EverMemOS not configured, showing config alert")
            showConfigAlert = true
            return
        }

        dialogViewModel.onDismiss = {
            let talkingNPCs = Set(bridge.activeConversationNPCs)
            NHLogger.system.info("[System] onDismiss: talkingNPCs=\(talkingNPCs), brainManager=\(self.npcBrainManager != nil)")
            gameScene.setDialogActive(false)
            self.dialogueService?.onConversationEnded()
            NHLogger.system.info("[Dismiss] onConversationEnded called, talkingNPCs=\(talkingNPCs)")

            if let first = talkingNPCs.first, let second = talkingNPCs.dropFirst().first {
                gameState.zoneState.recordConversation(npcId: first, partnerId: second)
                gameState.zoneState.recordConversation(npcId: second, partnerId: first)
                NHLogger.system.info("[Dismiss] recordConversation: \(first)↔\(second)")
            }

            if let bm = self.npcBrainManager {
                NHLogger.system.info("[Dismiss] rescheduling NPCs...")
                bm.rescheduleNPCs(roster: roster, involvedNPCIds: talkingNPCs)

                let assignments = bm.currentZoneAssignments()
                NHLogger.system.info("[Dismiss] updateNPCPositions: \(assignments)")
                gameScene.updateNPCPositions(assignments)
                gameScene.applyCooldownVisuals(gameState.zoneState.cooldownNPCIds)
            } else {
                NHLogger.system.error("[Dismiss] npcBrainManager is nil!")
            }
        }
    }

}

// MARK: - Stroked Text

struct StrokedText: View {
    let text: String
    let fontSize: CGFloat
    let fillColor: Color
    let strokeColor: Color
    let strokeWidth: CGFloat

    var body: some View {
        let font = Font.system(size: fontSize, weight: .heavy, design: .rounded)
        ZStack {
            // Stroke layer: offset in 8 directions
            ForEach(offsets, id: \.0) { dx, dy in
                Text(text)
                    .font(font)
                    .foregroundStyle(strokeColor)
                    .offset(x: dx, y: dy)
            }
            // Fill layer on top
            Text(text)
                .font(font)
                .foregroundStyle(fillColor)
        }
    }

    private var offsets: [(CGFloat, CGFloat)] {
        let d = strokeWidth
        return [(d, d)]
    }
}
