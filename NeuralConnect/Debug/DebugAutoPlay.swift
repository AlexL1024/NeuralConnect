#if DEBUG
import Foundation

/// Headless debug mode: auto-ticks zones, triggers REAL AI-generated conversations,
/// stores memories, and logs everything for emergent narrative testing.
/// Uses NPCBrainManager for the full dialogue pipeline (same as real game).
@MainActor
final class DebugAutoPlay {
    private let gameState: GameState
    private let brainManager: NPCBrainManager?
    private let roster: [NPCCharacter]
    private var timer: Timer?
    private var tickCount = 0
    private let logFile: URL
    private var logLines: [String] = []
    private var conversationCount = 0
    private var isGenerating = false  // Prevent overlapping AI calls
    private let maxTicks: Int

    // Fallback scheduler only used when brainManager is nil
    private let fallbackScheduler = ZoneScheduler()

    init(gameState: GameState, roster: [NPCCharacter], brainManager: NPCBrainManager? = nil, maxTicks: Int = 80) {
        self.gameState = gameState
        self.roster = roster
        self.brainManager = brainManager
        self.maxTicks = maxTicks
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.logFile = docs.appendingPathComponent("debug_autoplay.log")
    }

    func start(interval: TimeInterval = 2.0) {
        logLines = []
        emit("========== DEBUG AUTOPLAY START ==========")
        emit("NPCs: \(roster.map(\.id))")
        emit("Using NPCBrainManager: \(brainManager != nil)")
        emit("DeepSeek configured: \(DeepSeekConfig.isConfigured)")
        emit("Max ticks: \(maxTicks), interval: \(interval)s")

        // Initialize zone state
        gameState.initialize(roster: roster)
        logZoneState("INIT")

        // Log initial relationship state
        logRelationships("INIT")

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.autoTick()
            }
        }
        emit("Timer started, interval=\(interval)s")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        emit("")
        emit("========== FINAL SUMMARY ==========")
        emit("Total ticks: \(tickCount), conversations: \(conversationCount)")
        logRelationships("FINAL")
        emit("========== STOPPED ==========")
        flush()
    }

    private func autoTick() {
        tickCount += 1
        emit("")
        emit("━━━ TICK #\(tickCount) (sched=\(gameState.zoneState.scheduleCount)) ━━━")

        // 1) If there's a pending conversation from last tick, run it with full AI
        var justTalked: [String] = []
        if let candidate = gameState.zoneState.pendingConversationCandidate, !isGenerating {
            justTalked = startConversation(candidate)
        }

        // 2) Run cognitive tick (advanceTick + zone scheduling + observations)
        let beforeZones = gameState.zoneState.npcZones

        if let bm = brainManager {
            bm.rescheduleNPCs(roster: roster, involvedNPCIds: Set(justTalked))
        } else {
            var rng = SystemRandomNumberGenerator()
            fallbackScheduler.tick(
                roster: roster,
                state: &gameState.zoneState,
                using: &rng
            )
        }

        let afterZones = gameState.zoneState.npcZones

        // Log movements
        let moved = beforeZones.filter { afterZones[$0.key] != $0.value }
        if !moved.isEmpty {
            for (npcId, oldZone) in moved.sorted(by: { $0.key < $1.key }) {
                let newZone = afterZones[npcId] ?? "?"
                emit("  MOVE \(npcId): \(oldZone) -> \(newZone)")
            }
        }

        logZoneState("RESULT")

        // Log pending conversation candidate
        if let c = gameState.zoneState.pendingConversationCandidate {
            emit("  NEXT PAIR: \(c.leftId) + \(c.rightId) in \(c.zoneId) (score:\(String(format: "%.1f", c.score)))")
        } else {
            emit("  NEXT PAIR: none")
        }

        flush()

        if tickCount >= maxTicks {
            stop()
        }
    }

    /// Start a full AI conversation (recall → intent → prompt → generate → summary → store).
    /// Returns participant IDs for busy marking. AI generation is async and fire-and-forget.
    @discardableResult
    private func startConversation(_ candidate: ConversationCandidate) -> [String] {
        let leftId = candidate.leftId
        let rightId = candidate.rightId
        conversationCount += 1

        emit("")
        emit("  ╔══ CONVERSATION #\(conversationCount): \(leftId) <-> \(rightId) in \(candidate.zoneId) ══╗")

        guard let bm = brainManager else {
            // Fallback: no brainManager, just apply casual outcomes
            emit("  ⚠️ No brainManager, applying casual outcomes only")
            gameState.applyOutcome(
                ConversationOutcome.forInitiator(mode: .casual, summary: ""),
                npcId: leftId, partnerId: rightId
            )
            gameState.applyOutcome(
                ConversationOutcome.forResponder(mode: .casual, summary: ""),
                npcId: rightId, partnerId: leftId
            )
            clearCandidate(leftId: leftId, rightId: rightId)
            return [leftId, rightId]
        }

        // Generate intent and log it
        let intent = bm.generateIntent(leftId: leftId, rightId: rightId)
        let relCtx = bm.relationshipContext(leftId: leftId, rightId: rightId)

        emit("  INTENT: mode=\(intent?.mode.rawValue ?? "nil")")
        emit("  WHY: \(intent?.whyNow ?? "nil")")
        emit("  SECRET_L: \(intent?.secretPressureActiveLeft ?? false) SECRET_R: \(intent?.secretPressureActiveRight ?? false)")
        emit("  REL: trust=\(relCtx.trustLR)/\(relCtx.trustRL) susp=\(relCtx.suspicionLR)/\(relCtx.suspicionRL) debt=\(relCtx.debtLR)/\(relCtx.debtRL) pres=\(relCtx.pressureL)/\(relCtx.pressureR)")

        // Apply outcomes synchronously (same as real game)
        bm.applyConversationOutcomes(leftId: leftId, rightId: rightId, intent: intent)
        clearCandidate(leftId: leftId, rightId: rightId)

        // Fire async AI generation
        isGenerating = true
        Task {
            await self.generateFullConversation(
                leftId: leftId, rightId: rightId,
                zoneId: candidate.zoneId,
                intent: intent, relCtx: relCtx
            )
            self.isGenerating = false
        }

        return [leftId, rightId]
    }

    /// Full AI pipeline: recall memories → build prompt → generate dialogue → store summaries.
    private func generateFullConversation(
        leftId: String, rightId: String, zoneId: String,
        intent: ConversationIntent?, relCtx: RelationshipContext
    ) async {
        guard let bm = brainManager,
              let leftChar = NPCRoster.character(id: leftId),
              let rightChar = NPCRoster.character(id: rightId) else {
            emit("  ⚠️ Missing character data for \(leftId) or \(rightId)")
            flush()
            return
        }

        // 1. Recall memories + reflections + recent phrases
        let memories = await bm.recallForConversation(leftId: leftId, rightId: rightId)
        let leftPhrases = await bm.recentPhrases(npcId: leftId)
        let rightPhrases = await bm.recentPhrases(npcId: rightId)
        if !memories.left.isEmpty {
            emit("  MEM[\(leftChar.name)→\(rightChar.name)]: \(memories.left.joined(separator: " | "))")
        }
        if !memories.right.isEmpty {
            emit("  MEM[\(rightChar.name)→\(leftChar.name)]: \(memories.right.joined(separator: " | "))")
        }
        if !memories.leftForesights.isEmpty {
            emit("  FORE[\(leftChar.name)]: \(memories.leftForesights.joined(separator: " | "))")
        }
        if !memories.rightForesights.isEmpty {
            emit("  FORE[\(rightChar.name)]: \(memories.rightForesights.joined(separator: " | "))")
        }
        if !leftPhrases.isEmpty {
            emit("  DEDUP[\(leftChar.name)]: \(leftPhrases.joined(separator: " | "))")
        }
        if !rightPhrases.isEmpty {
            emit("  DEDUP[\(rightChar.name)]: \(rightPhrases.joined(separator: " | "))")
        }

        // 2. Build the prompt (log it so we can verify goals/agendas are injected)
        let userPrompt = PromptBuilder.conversationPrompt(
            left: leftChar, right: rightChar,
            locationName: zoneId,
            leftMemories: memories.left,
            rightMemories: memories.right,
            leftForesights: memories.leftForesights,
            rightForesights: memories.rightForesights,
            leftRecentPhrases: leftPhrases,
            rightRecentPhrases: rightPhrases,
            intent: intent,
            trustLR: relCtx.trustLR, trustRL: relCtx.trustRL,
            suspicionLR: relCtx.suspicionLR, suspicionRL: relCtx.suspicionRL,
            debtLR: relCtx.debtLR, debtRL: relCtx.debtRL,
            pressureL: relCtx.pressureL, pressureR: relCtx.pressureR
        )
        emit("  ── PROMPT ──")
        for line in userPrompt.components(separatedBy: "\n") {
            emit("  │ \(line)")
        }
        emit("  ── END PROMPT ──")

        // 3. Generate dialogue via DeepSeek (or Apple AI)
        let leftDesc = AgentDotDescriptor(character: leftChar)
        let rightDesc = AgentDotDescriptor(character: rightChar)
        let group = ConversationGroupDescriptor(
            id: "\(leftId)_\(rightId)_\(conversationCount)",
            locationId: zoneId,
            locationName: zoneId,
            left: leftDesc,
            right: rightDesc
        )
        let context = ConversationContext(
            group: group,
            leftCharacter: leftChar,
            rightCharacter: rightChar,
            leftMemories: memories.left,
            rightMemories: memories.right,
            leftForesights: memories.leftForesights,
            rightForesights: memories.rightForesights,
            leftRecentPhrases: leftPhrases,
            rightRecentPhrases: rightPhrases,
            intent: intent,
            relationshipContext: relCtx
        )

        let provider: DialogueProvider
        if DeepSeekConfig.isConfigured {
            provider = DeepSeekDialogueProvider()
        } else {
            provider = FallbackDialogueProvider(note: "No AI configured")
        }

        let conversation = await provider.generateConversation(context: context)

        // 4. Log the generated dialogue
        emit("  ── DIALOGUE (\(conversation.lines.count) lines) ──")
        for line in conversation.lines {
            let tag = line.speaker == .left ? leftChar.localizedName : rightChar.localizedName
            emit("  │ \(tag): \(line.text)")
        }
        emit("  ╚══ END CONVERSATION #\(conversationCount) ══╝")

        // 4b. Record spoken lines for anti-repetition
        let spokenLeft = conversation.lines.filter { $0.speaker == .left }.map(\.text)
        let spokenRight = conversation.lines.filter { $0.speaker == .right }.map(\.text)
        await bm.recordLines(npcId: leftId, lines: spokenLeft)
        await bm.recordLines(npcId: rightId, lines: spokenRight)

        // 5. Generate and store summaries (same as real game)
        if conversation.lines.count > 1 {
            let ln = leftChar.localizedName
            let rn = rightChar.localizedName
            let dialogueTexts = conversation.lines.map { line in
                switch line.speaker {
                case .left: return "\(ln): \(line.text)"
                case .right: return "\(rn): \(line.text)"
                }
            }

            let leftSummary = await generateSummary(
                npcName: ln, partnerName: rn,
                dialogue: dialogueTexts,
                temperature: leftChar.aiTemperature
            )
            let rightSummary = await generateSummary(
                npcName: rn, partnerName: ln,
                dialogue: dialogueTexts,
                temperature: rightChar.aiTemperature
            )

            emit("  SUMMARY[\(ln)]: \(leftSummary)")
            emit("  SUMMARY[\(rn)]: \(rightSummary)")

            await bm.storeSummaries(
                leftId: leftId, rightId: rightId,
                leftName: ln, rightName: rn,
                leftSummary: leftSummary, rightSummary: rightSummary
            )
        }

        // 6. Log updated relationships after this conversation
        logRelationships("POST-CONV#\(conversationCount)")
        flush()
    }

    private func clearCandidate(leftId: String, rightId: String) {
        gameState.zoneState.recordConversation(npcId: leftId, partnerId: rightId)
        gameState.zoneState.recordConversation(npcId: rightId, partnerId: leftId)
        gameState.zoneState.pendingConversationCandidate = nil
    }

    /// Generate summary using same approach as DialogueService.
    private nonisolated func generateSummary(
        npcName: String, partnerName: String,
        dialogue: [String],
        temperature: Double
    ) async -> String {
        let prompt = PromptBuilder.summaryPrompt(
            npcName: npcName, partnerName: partnerName,
            dialogue: dialogue
        )

        let summarySystem = LanguageManager.shared.isEnglish
            ? "You are a memory summarization assistant. Output only one summary sentence, nothing else."
            : "你是记忆总结助手。只输出一句简体中文总结，不要任何其他内容。不要使用英文。"

        if DeepSeekConfig.isConfigured {
            do {
                let result = try await DeepSeekAPI.generate(
                    system: summarySystem,
                    user: prompt,
                    maxTokens: 120,
                    temperature: temperature
                )
                if !result.isEmpty { return result }
            } catch { }
        }

        return L(
            "\(npcName) had a conversation with \(partnerName).",
            "\(npcName)和\(partnerName)进行了一次对话。"
        )
    }

    // MARK: - Logging

    private func logZoneState(_ label: String) {
        var distribution: [String: [String]] = [:]
        for (npcId, zone) in gameState.zoneState.npcZones {
            distribution[zone, default: []].append(npcId)
        }
        let summary = distribution
            .sorted(by: { $0.key < $1.key })
            .map { z in
                let npcs = z.value.sorted().joined(separator: ",")
                return "\(z.key)[\(npcs)]"
            }
            .joined(separator: "  ")
        emit("  [\(label)] \(summary)")
    }

    private func logRelationships(_ label: String) {
        let rs = gameState.zoneState
        emit("  ── RELATIONSHIPS [\(label)] ──")
        for npc in roster {
            var parts: [String] = []
            for other in roster where other.id != npc.id {
                let t = rs.trust(from: npc.id, to: other.id)
                let s = rs.suspicion(from: npc.id, to: other.id)
                let d = rs.debt(from: npc.id, to: other.id)
                if t > 0 || s > 0 || d != 0 {
                    parts.append("\(other.id)(t=\(t) s=\(s) d=\(d))")
                }
            }
            let p = rs.pressure(for: npc.id)
            if !parts.isEmpty || p > 0 {
                emit("  │ \(npc.id) [p=\(p)]: \(parts.joined(separator: " "))")
            }
        }
    }

    private func emit(_ line: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        logLines.append("[\(ts)] \(line)")
        print("[DebugAuto] \(line)")
    }

    private func flush() {
        let content = logLines.joined(separator: "\n") + "\n"
        try? content.write(to: logFile, atomically: true, encoding: .utf8)
    }
}
#endif
