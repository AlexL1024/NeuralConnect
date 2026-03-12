//
//  GameScene.swift
//  NeuralConnect
//
//  Created by Tao Liang on 3/4/26.
//

import SpriteKit
import Combine
import os.log

struct AgentDotDescriptor: Equatable {
    let id: String
    let displayName: String
    let role: String
    let archetype: String
    let speechStyle: String
    let spriteImage: String

    init(character: NPCCharacter) {
        self.id = character.id
        self.displayName = character.localizedName
        self.role = character.localizedRole
        self.archetype = character.localizedArchetype
        self.speechStyle = character.localizedSpeechStyle
        self.spriteImage = character.spriteImage
    }
}

struct ConversationGroupDescriptor: Equatable {
    let id: String
    let locationId: String
    let locationName: String
    let left: AgentDotDescriptor
    let right: AgentDotDescriptor
}

// MARK: - Observable bridge for SwiftUI

@MainActor @Observable
final class GameSceneBridge {
    var hackableNPCId: String? = nil
    var hackableNPCName: String? = nil
    var pendingConversation: ConversationGroupDescriptor? = nil
    var currentZoneName: String? = nil
    var playerNormalizedPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var activeConversationNPCs: [String] = []
    var playerDidMove = false
    let proximityEvent = PassthroughSubject<ConversationGroupDescriptor, Never>()
}

// MARK: - GameScene

class GameScene: SKScene {

    let bridge = GameSceneBridge()

    /// Single source of truth for NPC state — set by GameContainerView after init.
    var gameState: GameState?

    private var lastUpdateTime: TimeInterval = 0
    private var player: SKNode?
    private var cameraNode: SKCameraNode?
    private var moveTarget: CGPoint?
    private var proximityCheckAccumulator: TimeInterval = 0
    private(set) var shipZones: [ShipZone] = []

    // Individual NPC nodes keyed by NPC id
    private var npcNodes: [String: SKNode] = [:]
    private var npcCharacters: [String: NPCCharacter] = [:]

    private let playerRadius: CGFloat = 48
    private let playerSpeed: CGFloat = 260
    private let agentDotRadius: CGFloat = 9

    private var isDialogActive: Bool = false

    /// Zone that was just used for dialog/hack — must leave and re-enter to trigger again.
    private var lastTriggeredZoneId: String?

    // Zone dwell tracking (prevents accidental triggers when passing through)
    private var zoneDwellId: String?
    private var zoneDwellStart: TimeInterval = 0
    private let zoneDwellThreshold: TimeInterval = 2.0

    // World bounds (set during buildShuttleZones)
    private var worldRect: CGRect = .zero

    // Zone map pixel sampler for irregular zone detection
    private var zoneMapSampler: ZoneMapSampler?
    private var backdropFrame: CGRect = .zero

    override func didMove(to view: SKView) {
        lastUpdateTime = 0
        proximityCheckAccumulator = 0

        physicsWorld.gravity = .zero
        let worldRect = frame.insetBy(dx: -680, dy: -320)
        self.worldRect = worldRect
        physicsBody = SKPhysicsBody(edgeLoopFrom: worldRect)
        physicsBody?.friction = 0

        buildBackdrop(in: worldRect)
        // Constrain player to backdrop bounds so they can't walk off the map
        if backdropFrame.width > 0 {
            physicsBody = SKPhysicsBody(edgeLoopFrom: backdropFrame)
            physicsBody?.friction = 0
            physicsBody?.categoryBitMask = 0x2
        }
        buildSunParticles(in: worldRect)
        buildShuttleZones(in: worldRect)

        let playerNode = makeCircularAvatar(imageName: "Player2d_A", size: 90, borderColor: .black, name: "player")
        playerNode.position = CGPoint(x: worldRect.midX, y: worldRect.minY + worldRect.height * 0.2)
        playerNode.zPosition = 10
        let playerCategory: UInt32 = 0x1
        let wallCategory: UInt32 = 0x2
        playerNode.physicsBody = SKPhysicsBody(circleOfRadius: playerRadius)
        playerNode.physicsBody?.allowsRotation = false
        playerNode.physicsBody?.linearDamping = 0
        playerNode.physicsBody?.friction = 0
        playerNode.physicsBody?.restitution = 0
        playerNode.physicsBody?.categoryBitMask = playerCategory
        playerNode.physicsBody?.collisionBitMask = wallCategory
        self.player = playerNode
        addChild(playerNode)

        let cameraNode = SKCameraNode()
        self.cameraNode = cameraNode
        self.camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = playerNode.position

        spawnNPCs()
    }

    override func didSimulatePhysics() {
        guard let player, let cameraNode else { return }
        cameraNode.position = clampedCameraPosition(for: player.position)
    }

    /// Clamp camera so the visible area never extends beyond the backdrop.
    private func clampedCameraPosition(for target: CGPoint) -> CGPoint {
        guard backdropFrame.width > 0, backdropFrame.height > 0 else { return target }

        let viewHalfW = size.width / 2
        let viewHalfH = size.height / 2

        let minX = backdropFrame.minX + viewHalfW
        let maxX = backdropFrame.maxX - viewHalfW
        let minY = backdropFrame.minY + viewHalfH
        let maxY = backdropFrame.maxY - viewHalfH

        return CGPoint(
            x: min(max(target.x, minX), maxX),
            y: min(max(target.y, minY), maxY)
        )
    }

    private func setMoveTarget(_ pos: CGPoint) {
        moveTarget = pos
    }

    func setDialogActive(_ active: Bool) {
        isDialogActive = active
        moveTarget = nil
        player?.physicsBody?.velocity = .zero

        if active {
            isPaused = true
            bridge.hackableNPCId = nil
            bridge.hackableNPCName = nil
            bridge.pendingConversation = nil
            removeAllSpeechBubbles()
            // Lock current zone — player must leave and re-enter to trigger again
            lastTriggeredZoneId = playerCurrentZone()?.id
        } else {
            isPaused = false
            bridge.activeConversationNPCs = []
        }
    }

    /// Manually trigger a pending conversation (called from UI button).
    func triggerPendingConversation() {
        guard let descriptor = bridge.pendingConversation else { return }
        bridge.pendingConversation = nil
        removeAllSpeechBubbles()
        bridge.activeConversationNPCs = [descriptor.left.id, descriptor.right.id]
        setDialogActive(true)
        bridge.proximityEvent.send(descriptor)
    }

    // MARK: - NPC Spawning (individual dots)

    private func spawnNPCs() {
        let roster = NPCRoster.all
        for npc in roster {
            npcCharacters[npc.id] = npc

            let initialZoneId = npc.id == "ai_android" ? "energy" : (npc.preferredZones.first ?? "bar")
            let position = positionInZone(initialZoneId, index: npcNodes.count % 2)

            let descriptor = AgentDotDescriptor(character: npc)
            let node = makeAgentSprite(descriptor: descriptor, color: SKColor(hex: npc.dotColorHex), position: position)
            node.userData?["zoneId"] = initialZoneId
            npcNodes[npc.id] = node
            addChild(node)
        }
    }

    /// Update NPC positions when zones change.
    func updateNPCPositions(_ zoneAssignments: [String: String]) {
        var npcsPerZone: [String: [String]] = [:]
        for (npcId, zoneId) in zoneAssignments {
            npcsPerZone[zoneId, default: []].append(npcId)
        }

        for (zoneId, npcIds) in npcsPerZone {
            for (index, npcId) in npcIds.sorted().enumerated() {
                guard let node = npcNodes[npcId] else { continue }
                node.userData?["zoneId"] = zoneId
                node.position = positionInZone(zoneId, index: index)
            }
        }
    }

    private func makeAgentSprite(
        descriptor: AgentDotDescriptor,
        color: SKColor,
        position: CGPoint
    ) -> SKNode {
        let spriteSize: CGFloat = 90
        let container = makeCircularAvatar(imageName: descriptor.spriteImage, size: spriteSize, borderColor: color, name: "agent:\(descriptor.id)")
        container.position = position
        container.zPosition = 9

        // Name label
        let radius = spriteSize / 2
        let label = SKLabelNode(text: descriptor.displayName)
        label.fontSize = 10
        label.fontName = "Menlo"
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: radius + 10)
        label.zPosition = 2
        container.addChild(label)

        container.userData = [
            "displayName": descriptor.displayName,
            "npcId": descriptor.id,
        ]
        // No physics body — proximity is zone-based, not collision-based

        return container
    }

    /// Creates a circular avatar node: image cropped to circle with colored border.
    /// Non-square images keep aspect ratio with white fill behind.
    private func makeCircularAvatar(imageName: String, size: CGFloat, borderColor: SKColor, name: String) -> SKNode {
        let radius = size / 2

        let container = SKNode()
        container.name = name

        // Sprite (no background circle or border — transparent background)
        let cropNode = SKCropNode()
        cropNode.zPosition = 2

        let sprite = SKSpriteNode(imageNamed: imageName)
        // Preserve aspect ratio: scale to fill the longer edge
        if let tex = sprite.texture {
            let texW = tex.size().width
            let texH = tex.size().height
            if texW > texH {
                // Wider than tall — fit height to size, width overflows
                sprite.size = CGSize(width: size * texW / texH, height: size)
            } else {
                // Taller than wide — fit width to size, height overflows
                sprite.size = CGSize(width: size, height: size * texH / texW)
            }
        } else {
            sprite.size = CGSize(width: size, height: size)
        }
        cropNode.addChild(sprite)
        container.addChild(cropNode)

        return container
    }

    // MARK: - Zone Helpers

    private func positionInZone(_ zoneId: String, index: Int) -> CGPoint {
        guard let zone = shipZones.first(where: { $0.id == zoneId }) else {
            return .zero
        }
        guard !zone.anchors.isEmpty else { return .zero }
        let anchor = zone.anchors[index % zone.anchors.count]
        return anchor
    }

    func playerCurrentZone() -> ShipZone? {
        guard let playerPos = player?.position,
              let sampler = zoneMapSampler else { return nil }
        guard let zoneId = sampler.zoneId(atScenePosition: playerPos, backdropFrame: backdropFrame) else {
            return nil
        }
        return shipZones.first { $0.id == zoneId }
    }

    func npcIdsInZone(_ zoneId: String) -> [String] {
        gameState?.zoneState.npcsInZone(zoneId) ?? []
    }

    /// Set cooldown visuals: dim cooldown NPCs, restore others.
    func applyCooldownVisuals(_ cooldownIds: Set<String>) {
        for (npcId, node) in npcNodes {
            node.alpha = cooldownIds.contains(npcId) ? 0.4 : 1.0
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isDialogActive else { return }
        guard let t = touches.first else { return }
        let pos = t.location(in: self)
        setMoveTarget(pos)
        showTapIndicator(at: pos)
        if !bridge.playerDidMove {
            bridge.playerDidMove = true
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isDialogActive else { return }
        guard let t = touches.first else { return }
        setMoveTarget(t.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isDialogActive else { return }
        guard let t = touches.first else { return }
        setMoveTarget(t.location(in: self))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        moveTarget = nil
        player?.physicsBody?.velocity = .zero
    }

    private func showTapIndicator(at pos: CGPoint) {
        let dot = SKShapeNode(circleOfRadius: 10)
        dot.fillColor = .white
        dot.strokeColor = .clear
        dot.alpha = 0.9
        dot.position = pos
        dot.zPosition = 50
        dot.setScale(1.0)
        addChild(dot)

        let expand = SKAction.group([
            SKAction.scale(to: 2.0, duration: 0.5),
            SKAction.fadeOut(withDuration: 0.5),
        ])
        expand.timingMode = .easeOut
        dot.run(expand) { dot.removeFromParent() }
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        var dt: TimeInterval = 0
        if lastUpdateTime > 0 {
            dt = currentTime - lastUpdateTime
            if dt < 0 { dt = 0 }
            if dt > 0.25 { dt = 0.25 }
        }
        lastUpdateTime = currentTime

        if !isDialogActive {
            proximityCheckAccumulator += dt
        } else {
            proximityCheckAccumulator = 0
        }

        if proximityCheckAccumulator >= 0.2 {
            proximityCheckAccumulator = 0
            checkNPCProximity()
        }

        // Player movement
        if let target = moveTarget, let player = player, let body = player.physicsBody {
            let dx = target.x - player.position.x
            let dy = target.y - player.position.y
            let dist = sqrt(dx * dx + dy * dy)

            if dist < 6 {
                moveTarget = nil
                body.velocity = .zero
            } else {
                let vx = (dx / dist) * playerSpeed
                let vy = (dy / dist) * playerSpeed
                body.velocity = CGVector(dx: vx, dy: vy)
            }
        }

        updateNormalizedPosition()
    }

    private func updateNormalizedPosition() {
        guard let player = player else { return }
        guard worldRect.width > 0, worldRect.height > 0 else { return }
        let nx = (player.position.x - worldRect.minX) / worldRect.width
        let ny = 1.0 - (player.position.y - worldRect.minY) / worldRect.height // flip Y for minimap
        bridge.playerNormalizedPosition = CGPoint(
            x: min(max(nx, 0), 1),
            y: min(max(ny, 0), 1)
        )
    }

    // MARK: - Speech Bubble

    private let speechBubbleName = "speechBubble"

    private func showSpeechBubble(on npcId: String) {
        guard let node = npcNodes[npcId] else { return }
        guard node.childNode(withName: speechBubbleName) == nil else { return }

        let bubble = SKNode()
        bubble.name = speechBubbleName
        bubble.zPosition = 20

        // Rounded rect background
        let bgSize = CGSize(width: 36, height: 20)
        let bg = SKShapeNode(rect: CGRect(origin: CGPoint(x: -bgSize.width / 2, y: -bgSize.height / 2), size: bgSize), cornerRadius: 6)
        bg.fillColor = SKColor(white: 0, alpha: 0.7)
        bg.strokeColor = .clear
        bubble.addChild(bg)

        // Animated dots
        let dotSpacing: CGFloat = 8
        for i in 0..<3 {
            let dot = SKShapeNode(circleOfRadius: 2.5)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.position = CGPoint(x: CGFloat(i - 1) * dotSpacing, y: 0)
            let delay = SKAction.wait(forDuration: Double(i) * 0.2)
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.4),
                SKAction.fadeAlpha(to: 1.0, duration: 0.4),
            ])
            dot.run(SKAction.sequence([delay, SKAction.repeatForever(pulse)]))
            bubble.addChild(dot)
        }

        // Position at top-right of avatar
        let avatarRadius: CGFloat = 45
        bubble.position = CGPoint(x: avatarRadius * 0.6, y: avatarRadius * 0.7)
        node.addChild(bubble)
    }

    private func removeSpeechBubble(from npcId: String) {
        guard let node = npcNodes[npcId] else { return }
        node.childNode(withName: speechBubbleName)?.removeFromParent()
    }

    private func removeAllSpeechBubbles() {
        for npcId in npcNodes.keys {
            removeSpeechBubble(from: npcId)
        }
    }

    // MARK: - Proximity Detection

    /// Simple zone-based trigger:
    /// - 2+ NPCs → conversation
    /// - 1 NPC → hackable
    /// - After trigger, zone is locked until player leaves and re-enters.
    private func checkNPCProximity() {
        let now = ProcessInfo.processInfo.systemUptime

        guard let zone = playerCurrentZone() else {
            // Left all zones — clear everything
            lastTriggeredZoneId = nil
            zoneDwellId = nil
            bridge.hackableNPCId = nil
            bridge.hackableNPCName = nil
            bridge.currentZoneName = nil
            bridge.pendingConversation = nil
            removeAllSpeechBubbles()
            return
        }

        bridge.currentZoneName = zone.name

        // Changed zone — clear lock
        if zoneDwellId != zone.id {
            zoneDwellId = zone.id
            bridge.hackableNPCId = nil
            bridge.hackableNPCName = nil
            if lastTriggeredZoneId != zone.id {
                lastTriggeredZoneId = nil
            }
        }

        // Already triggered here — must leave first
        if lastTriggeredZoneId == zone.id { return }

        // Only trigger when player has stopped moving
        if moveTarget != nil { return }

        // Check NPCs (exclude cooldown NPCs)
        let allNpcs = npcIdsInZone(zone.id)
        let npcs = allNpcs.filter { !(gameState?.zoneState.isCooldown($0) ?? false) }

        if npcs.count >= 2 {
            // 2+ NPCs — prepare conversation, wait for manual trigger
            if bridge.pendingConversation == nil {
                guard let (leftId, rightId) = pickNPCPair(for: zone.id) else { return }
                guard let leftChar = npcCharacters[leftId],
                      let rightChar = npcCharacters[rightId] else { return }

                let desc = ConversationGroupDescriptor(
                    id: "\(zone.id)_\(leftId)_\(rightId)",
                    locationId: zone.id,
                    locationName: zone.name,
                    left: AgentDotDescriptor(character: leftChar),
                    right: AgentDotDescriptor(character: rightChar)
                )
                bridge.pendingConversation = desc
                showSpeechBubble(on: desc.left.id)
                showSpeechBubble(on: desc.right.id)
            }
            bridge.hackableNPCId = nil
            bridge.hackableNPCName = nil

        } else if npcs.count == 1 {
            // Solo NPC — hackable
            bridge.hackableNPCId = npcs[0]
            bridge.hackableNPCName = npcCharacters[npcs[0]]?.localizedName
            if bridge.pendingConversation != nil {
                bridge.pendingConversation = nil
                removeAllSpeechBubbles()
            }

        } else {
            bridge.hackableNPCId = nil
            bridge.hackableNPCName = nil
            if bridge.pendingConversation != nil {
                bridge.pendingConversation = nil
                removeAllSpeechBubbles()
            }
        }
    }

    /// Pick 2 NPCs — prefer scheduler's pending candidate.
    private func pickNPCPair(for zoneId: String) -> (String, String)? {
        if let c = gameState?.zoneState.pendingConversationCandidate,
           c.zoneId == zoneId {
            let inZone = npcIdsInZone(zoneId)
            if inZone.contains(c.leftId) && inZone.contains(c.rightId) {
                gameState?.zoneState.pendingConversationCandidate = nil
                return (c.leftId, c.rightId)
            }
        }
        let candidates = npcIdsInZone(zoneId).shuffled()
        guard candidates.count >= 2 else { return nil }
        return (candidates[0], candidates[1])
    }
}

// MARK: - Ship Zone Data

extension GameScene {
    struct ShipZone: Equatable {
        let id: String
        let name: String
        let anchors: [CGPoint]
    }
}

// MARK: - Backdrop

private extension GameScene {
    func buildBackdrop(in worldRect: CGRect) {
        guard let image = UIImage(named: "TheMap"),
              let texture = image.cgImage != nil ? SKTexture(image: image) : nil else {
            NHLogger.scene.error("[GameScene] TheMap image not found")
            return
        }

        let backdrop = SKSpriteNode(texture: texture)
        // Scale to cover world rect while preserving aspect ratio
        let imageAspect = texture.size().width / texture.size().height
        let worldAspect = worldRect.width / worldRect.height

        if imageAspect > worldAspect {
            backdrop.size = CGSize(width: worldRect.height * imageAspect, height: worldRect.height)
        } else {
            backdrop.size = CGSize(width: worldRect.width, height: worldRect.width / imageAspect)
        }

        backdrop.position = CGPoint(x: worldRect.midX, y: worldRect.midY)
        backdrop.zPosition = -25
        backdrop.name = "backdrop"
        addChild(backdrop)

        // Store backdrop frame for zone map coordinate mapping
        backdropFrame = CGRect(
            x: backdrop.position.x - backdrop.size.width / 2,
            y: backdrop.position.y - backdrop.size.height / 2,
            width: backdrop.size.width,
            height: backdrop.size.height
        )

        // Initialize zone map sampler
        zoneMapSampler = ZoneMapSampler()
        if zoneMapSampler == nil {
            NHLogger.scene.warning("[GameScene] ZoneMap not available — zone detection disabled")
        }

        NHLogger.scene.info("[GameScene] TheMap backdrop loaded (\(backdrop.size.width) x \(backdrop.size.height))")
    }
}

// MARK: - Sun Particles

private extension GameScene {

    func buildSunParticles(in worldRect: CGRect) {
        // The orb sits center-horizontally, roughly 65% up from bottom of the map
        let sunCenter = CGPoint(x: worldRect.midX, y: worldRect.minY + worldRect.height * 0.65)

        // --- Core glow (invisible, kept for structure) ---
        let coreGlow = SKShapeNode(circleOfRadius: 30)
        coreGlow.fillColor = .clear
        coreGlow.strokeColor = .clear
        coreGlow.glowWidth = 0
        coreGlow.position = sunCenter
        coreGlow.zPosition = -18
        addChild(coreGlow)

        // --- Radial light rays (circular emitters pointing outward) ---
        // Generate a soft circular texture for the particles
        let texSize = 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: texSize, height: texSize))
        let particleImage = renderer.image { ctx in
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor.white.cgColor, UIColor.clear.cgColor] as CFArray,
                locations: [0.0, 1.0]
            )!
            ctx.cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: texSize / 2, y: texSize / 2), startRadius: 0,
                endCenter: CGPoint(x: texSize / 2, y: texSize / 2), endRadius: CGFloat(texSize / 2),
                options: .drawsAfterEndLocation
            )
        }
        let emitter = SKEmitterNode()
        emitter.particleTexture = SKTexture(image: particleImage)
        emitter.particleBirthRate = 3000
        emitter.numParticlesToEmit = 0
        emitter.particleLifetime = 62.5
        emitter.particleLifetimeRange = 25.0

        emitter.particlePositionRange = CGVector(dx: 20, dy: 20) // small spread at origin

        emitter.particleSpeed = 30
        emitter.particleSpeedRange = 20
        emitter.emissionAngleRange = .pi * 2 // radiate outward in all directions

        emitter.particleAlpha = 0.6
        emitter.particleAlphaRange = 0.3
        emitter.particleAlphaSpeed = -0.01

        emitter.particleScale = 0.16
        emitter.particleScaleRange = 0.08
        emitter.particleScaleSpeed = -0.04

        emitter.particleColor = SKColor(red: 1.0, green: 0.75, blue: 0.3, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                SKColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 1.0),
                SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.8),
                SKColor(red: 1.0, green: 0.3, blue: 0.1, alpha: 0.0),
            ],
            times: [0, 0.4, 1.0]
        )

        emitter.particleBlendMode = .add
        emitter.position = CGPoint(x: sunCenter.x + 10, y: sunCenter.y + 15)
        emitter.zPosition = -17
        emitter.targetNode = self
        addChild(emitter)

        // --- Soft outer halo (large faint ring) ---
        let halo = SKShapeNode(circleOfRadius: 100)
        halo.fillColor = SKColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.08)
        halo.strokeColor = .clear
        halo.glowWidth = 40
        halo.position = sunCenter
        halo.zPosition = -19
        halo.blendMode = .add
        addChild(halo)

        let haloUp = SKAction.group([
            SKAction.scale(to: 1.15, duration: 3.0),
            SKAction.fadeAlpha(to: 0.12, duration: 3.0),
        ])
        haloUp.timingMode = .easeInEaseOut
        let haloDown = SKAction.group([
            SKAction.scale(to: 0.85, duration: 3.0),
            SKAction.fadeAlpha(to: 0.05, duration: 3.0),
        ])
        haloDown.timingMode = .easeInEaseOut
        halo.run(.repeatForever(.sequence([haloUp, haloDown])))
    }
}

// MARK: - Zone Building

private extension GameScene {

    func buildShuttleZones(in worldRect: CGRect) {
        let midX = worldRect.midX
        let midY = worldRect.midY

        // Convert UV (0,0=top-left, 1,1=bottom-right of image) → scene coordinates
        func uvToScene(_ uv: CGPoint) -> CGPoint {
            CGPoint(
                x: backdropFrame.minX + uv.x * backdropFrame.width,
                y: backdropFrame.maxY - uv.y * backdropFrame.height  // Y flip
            )
        }

        shipZones = ShuttleLayout.zones.map { layoutZone in
            ShipZone(
                id: layoutZone.id,
                name: layoutZone.localizedName,
                anchors: layoutZone.anchorUVs.map { uvToScene($0) }
            )
        }

        _ = midX
        _ = midY

        // Anchor pins only (no zone labels on map)
        for (_, shipZone) in zip(ShuttleLayout.zones, shipZones) {
            for p in shipZone.anchors {
                let pin = SKShapeNode(circleOfRadius: 4)
                pin.fillColor = .white
                pin.strokeColor = .clear
                pin.alpha = 0.35
                pin.position = p
                pin.zPosition = -8
                addChild(pin)
            }
        }
    }

    func addNeonLine(from a: CGPoint, to b: CGPoint, color: SKColor) {
        let path = CGMutablePath()
        path.move(to: a)
        path.addLine(to: b)
        let line = SKShapeNode(path: path)
        line.strokeColor = color.withAlphaComponent(0.25)
        line.lineWidth = 6
        line.glowWidth = 10
        line.zPosition = -15
        addChild(line)

        let pulseOut = SKAction.fadeAlpha(to: 0.10, duration: 1.3)
        pulseOut.timingMode = .easeInEaseOut
        let pulseIn = SKAction.fadeAlpha(to: 0.30, duration: 1.3)
        pulseIn.timingMode = .easeInEaseOut
        line.run(.repeatForever(.sequence([pulseOut, pulseIn])))
    }
}

// MARK: - SKColor hex helper

private extension SKColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
