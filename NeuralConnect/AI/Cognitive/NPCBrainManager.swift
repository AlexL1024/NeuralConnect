import Foundation
import os.log
import EverMemOSKit

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Relationship values between two NPCs for prompt injection.
struct RelationshipContext {
    let trustLR: Int, trustRL: Int
    let suspicionLR: Int, suspicionRL: Int
    let debtLR: Int, debtRL: Int
    let pressureL: Int, pressureR: Int
}

/// Manages all NPC brains. Coordinates zone scheduling,
/// conversation hooks, and the cognitive tick.
@MainActor
final class NPCBrainManager {

    let gameState: GameState
    private let memoryStore: MemoryStore
    private let zoneScheduler = ZoneScheduler()
    private var brains: [String: NPCBrain] = [:]

    init(gameState: GameState, memoryStore: MemoryStore) {
        self.gameState = gameState
        self.memoryStore = memoryStore
    }

    // MARK: - Initialization

    /// Create brains and initialize game state (relationships loaded from UserDefaults).
    func initialize(roster: [NPCCharacter]) {
        for npc in roster {
            brains[npc.id] = NPCBrain(character: npc, memoryStore: memoryStore)
        }
        NHLogger.brain.info("[NPCBrainManager] Created \(self.brains.count) brains")

        gameState.initialize(roster: roster)
    }

    // MARK: - Zone Scheduling

    /// Advance all NPC positions. Call on a timer (~60s).
    func tickZones(roster: [NPCCharacter]) {
        var rng = SystemRandomNumberGenerator()
        zoneScheduler.tick(
            roster: roster,
            state: &gameState.zoneState,
            using: &rng
        )
    }

    // MARK: - Intent Generation

    /// Generate a rule-based ConversationIntent for a pair of NPCs.
    func generateIntent(leftId: String, rightId: String) -> ConversationIntent? {
        guard let leftChar = NPCRoster.character(id: leftId),
              let rightChar = NPCRoster.character(id: rightId) else { return nil }

        let rs = gameState.zoneState

        // Determine initiator: more unmet needs → initiator
        let leftNeedOverlap = Set(leftChar.needTags).intersection(rightChar.offerTags).count
        let rightNeedOverlap = Set(rightChar.needTags).intersection(leftChar.offerTags).count
        let leftDebt = rs.debt(from: leftId, to: rightId)
        let rightDebt = rs.debt(from: rightId, to: leftId)
        let leftPressure = rs.pressure(for: leftId)
        let rightPressure = rs.pressure(for: rightId)

        let initiatorIsLeft: Bool
        if leftNeedOverlap != rightNeedOverlap {
            initiatorIsLeft = leftNeedOverlap > rightNeedOverlap
        } else if leftDebt != rightDebt {
            initiatorIsLeft = leftDebt > rightDebt
        } else {
            initiatorIsLeft = leftPressure <= rightPressure
        }

        let initiatorId = initiatorIsLeft ? leftId : rightId
        let responderId = initiatorIsLeft ? rightId : leftId
        let initiator = initiatorIsLeft ? leftChar : rightChar
        let responder = initiatorIsLeft ? rightChar : leftChar

        let debtToResponder = rs.debt(from: initiatorId, to: responderId)
        let overlap = Set(initiator.needTags).intersection(responder.offerTags)
        let suspOfInitiator = rs.suspicion(from: initiatorId, to: responderId)
        let suspOfResponder = rs.suspicion(from: responderId, to: initiatorId)
        let trustBetween = min(rs.trust(from: initiatorId, to: responderId),
                               rs.trust(from: responderId, to: initiatorId))

        // Mode selection (ordered rules per PLAN)
        let mode: InteractionMode
        let whyNow: String

        // Check if either NPC has an agenda about the other
        let initiatorAgendas = PromptBuilder.relevantAgendas(for: initiator, about: responder)
        let hasAgendaAboutOther = initiatorAgendas.first.map { agenda in
            [responder.name, responder.role].contains { agenda.contains($0) }
        } ?? false

        let iName = initiator.localizedName
        let rName = responder.localizedName
        let isEN = LanguageManager.shared.isEnglish

        if debtToResponder > 0 {
            mode = .repay
            whyNow = isEN ? "\(iName) owes \(rName) a favor and wants to repay" : "\(iName)欠\(rName)一个人情，想找机会还"
        } else if !overlap.isEmpty && suspOfInitiator < 3 && suspOfResponder < 3 {
            mode = .askHelp
            whyNow = isEN ? "\(iName) needs help with \(overlap.joined(separator: "/"))" : "\(iName)需要\(overlap.joined(separator: "/"))方面的帮助"
        } else if leftNeedOverlap > 0 && rightNeedOverlap > 0 {
            mode = .exchange
            whyNow = isEN ? "Both have needs — a mutual exchange" : "双方互有需求，进行交换"
        } else if suspOfInitiator >= 2 || suspOfResponder >= 2 {
            mode = .probe
            whyNow = isEN ? "One suspects the other and can't resist probing" : "一方对另一方有怀疑，忍不住要试探"
        } else if hasAgendaAboutOther {
            mode = .probe
            whyNow = isEN ? "\(iName) has been watching \(rName) and wants to probe" : "\(iName)一直在关注\(rName)，想借机试探"
        } else {
            mode = .casual
            let leftAgenda = PromptBuilder.relevantAgendas(for: leftChar, about: rightChar).first
                ?? leftChar.localizedAgendas.first ?? ""
            let rightAgenda = PromptBuilder.relevantAgendas(for: rightChar, about: leftChar).first
                ?? rightChar.localizedAgendas.first ?? ""
            if isEN {
                whyNow = "\(iName) thinks: \(initiatorIsLeft ? leftAgenda : rightAgenda); \(rName) thinks: \(initiatorIsLeft ? rightAgenda : leftAgenda)"
            } else {
                whyNow = "\(iName)想：\(initiatorIsLeft ? leftAgenda : rightAgenda)；\(rName)想：\(initiatorIsLeft ? rightAgenda : leftAgenda)"
            }
        }

        // Allowed topics
        var allowed = Array(overlap)
        let zone = rs.currentZone(for: leftId) ?? ""
        if !zone.isEmpty { allowed.append(zone) }

        // Forbidden topics
        let forbidden = isEN
            ? ["Directly naming the other's secret", "Directly questioning identity authenticity", "Interrogation-style pushing outside current mode"]
            : ["直接点名对方秘密", "直接质问身份真假", "脱离当前模式的审讯式推进"]

        // Secret gating
        let leftPres = rs.pressure(for: leftId)
        let rightPres = rs.pressure(for: rightId)
        let leftSusp = rs.suspicion(from: rightId, to: leftId)
        let rightSusp = rs.suspicion(from: leftId, to: rightId)
        let secretActiveLeft = leftPres >= 2 || leftSusp >= 2
        let secretActiveRight = rightPres >= 2 || rightSusp >= 2

        let intent = ConversationIntent(
            initiatorId: initiatorId,
            responderId: responderId,
            mode: mode,
            whyNow: whyNow,
            initiatorNeedTags: initiator.needTags,
            responderOfferTags: responder.offerTags,
            allowedTopics: allowed,
            forbiddenTopics: forbidden,
            secretPressureActiveLeft: secretActiveLeft,
            secretPressureActiveRight: secretActiveRight
        )

        NHLogger.brain.info("[NPCBrainManager] Intent: \(initiatorId)→\(responderId) mode=\(mode.rawValue) whyNow=\(whyNow)")
        return intent
    }

    // MARK: - Conversation Hooks

    /// Get recent phrases spoken by an NPC (for anti-repetition injection).
    func recentPhrases(npcId: String, limit: Int = 8) async -> [String] {
        guard let brain = brains[npcId] else { return [] }
        return await brain.recentPhrases(limit: limit)
    }

    /// Record dialogue lines an NPC just spoke.
    func recordLines(npcId: String, lines: [String]) async {
        guard let brain = brains[npcId] else { return }
        await brain.recordLines(lines)
    }

    /// Before a conversation: retrieve relevant memories and foresights for both NPCs.
    func recallForConversation(leftId: String, rightId: String) async -> (
        left: [String], right: [String],
        leftForesights: [String], rightForesights: [String]
    ) {
        guard let leftBrain = brains[leftId], let rightBrain = brains[rightId] else {
            NHLogger.brain.debug("[NPCBrainManager] Recall skipped: leftBrain=\(self.brains[leftId] != nil) rightBrain=\(self.brains[rightId] != nil)")
            return ([], [], [], [])
        }

        async let leftMemories = leftBrain.recallForDialogue(partnerId: rightId)
        async let rightMemories = rightBrain.recallForDialogue(partnerId: leftId)
        async let leftForesights = leftBrain.recallForesights(partnerId: rightId)
        async let rightForesights = rightBrain.recallForesights(partnerId: leftId)

        let (lm, rm, lf, rf) = await (leftMemories, rightMemories, leftForesights, rightForesights)
        NHLogger.brain.info("[NPCBrainManager] Recall done: \(leftId)=\(lm.count) mem+\(lf.count) foresight, \(rightId)=\(rm.count) mem+\(rf.count) foresight")
        return (lm, rm, lf, rf)
    }

    /// Get relationship values between two NPCs for prompt context.
    func relationshipContext(leftId: String, rightId: String) -> RelationshipContext {
        let rs = gameState.zoneState
        return RelationshipContext(
            trustLR: rs.trust(from: leftId, to: rightId),
            trustRL: rs.trust(from: rightId, to: leftId),
            suspicionLR: rs.suspicion(from: leftId, to: rightId),
            suspicionRL: rs.suspicion(from: rightId, to: leftId),
            debtLR: rs.debt(from: leftId, to: rightId),
            debtRL: rs.debt(from: rightId, to: leftId),
            pressureL: rs.pressure(for: leftId),
            pressureR: rs.pressure(for: rightId)
        )
    }

    /// Synchronously apply relationship deltas based on intent mode.
    /// Call this before the cognitive tick so pair scoring uses updated values.
    func applyConversationOutcomes(leftId: String, rightId: String, intent: ConversationIntent?) {
        let mode = intent?.mode ?? .casual
        let isLeftInitiator = intent?.initiatorId == leftId

        var leftOutcome: ConversationOutcome
        var rightOutcome: ConversationOutcome

        if isLeftInitiator {
            leftOutcome = .forInitiator(mode: mode, summary: "",
                                         fulfilledNeedTags: intent?.initiatorNeedTags ?? [])
            rightOutcome = .forResponder(mode: mode, summary: "",
                                          fulfilledNeedTags: intent?.responderOfferTags ?? [])
        } else {
            leftOutcome = .forResponder(mode: mode, summary: "",
                                         fulfilledNeedTags: intent?.responderOfferTags ?? [])
            rightOutcome = .forInitiator(mode: mode, summary: "",
                                          fulfilledNeedTags: intent?.initiatorNeedTags ?? [])
        }

        // Secret pressure leakage: if one NPC's secret was active,
        // the other party notices something off → gains suspicion
        if intent?.secretPressureActiveLeft == true {
            rightOutcome = rightOutcome.addingSuspicion(1)
        }
        if intent?.secretPressureActiveRight == true {
            leftOutcome = leftOutcome.addingSuspicion(1)
        }

        gameState.applyOutcome(leftOutcome, npcId: leftId, partnerId: rightId)
        gameState.applyOutcome(rightOutcome, npcId: rightId, partnerId: leftId)
        gameState.saveRelationships()

        NHLogger.brain.debug("[NPCBrainManager] Outcomes applied: \(leftId) ↔ \(rightId) mode=\(mode.rawValue)")

        triggerReflectionIfNeeded(npcId: leftId)
        triggerReflectionIfNeeded(npcId: rightId)
    }

    /// After a conversation: store summaries to EverMemOS (async, fire-and-forget).
    func storeSummaries(leftId: String, rightId: String,
                        leftName: String, rightName: String,
                        leftSummary: String, rightSummary: String) async {
        if let leftBrain = brains[leftId] {
            await leftBrain.storeInteraction(partnerId: rightId, partnerName: rightName, summary: leftSummary)
        }
        if let rightBrain = brains[rightId] {
            await rightBrain.storeInteraction(partnerId: leftId, partnerName: leftName, summary: rightSummary)
        }
        NHLogger.brain.info("[NPCBrainManager] Summaries stored: \(leftId) ↔ \(rightId)")

        // Auto-patch ConversationMeta tags from the stored memories' keywords/entities
        Task {
            await patchConversationTags(leftId: leftId, rightId: rightId, leftName: leftName, rightName: rightName)
        }
    }

    /// Extract tags from recent memory keywords/entities and patch ConversationMeta.
    private func patchConversationTags(leftId: String, rightId: String,
                                        leftName: String, rightName: String) async {
        // Ensure ConversationMeta exists for both directions
        let groupIdLR = "\(leftId)_about_\(rightId)"
        let groupIdRL = "\(rightId)_about_\(leftId)"
        let groupNameLR = "\(leftName)-\(L("about", "关于"))\(rightName)"
        let groupNameRL = "\(rightName)-\(L("about", "关于"))\(leftName)"

        await memoryStore.ensureConversationMeta(groupId: groupIdLR, groupName: groupNameLR, participants: [leftId, rightId])
        await memoryStore.ensureConversationMeta(groupId: groupIdRL, groupName: groupNameRL, participants: [rightId, leftId])

        // Fetch recent memories to extract keywords/entities as tags
        var tags = Set<String>()
        if let leftBrain = brains[leftId] {
            let memories = await leftBrain.fetchRecentPartnerMemories(partnerId: rightId, limit: 3)
            for mem in memories {
                tags.formUnion(mem.keywords ?? [])
                tags.formUnion(mem.linkedEntities ?? [])
            }
        }
        if let rightBrain = brains[rightId] {
            let memories = await rightBrain.fetchRecentPartnerMemories(partnerId: leftId, limit: 3)
            for mem in memories {
                tags.formUnion(mem.keywords ?? [])
                tags.formUnion(mem.linkedEntities ?? [])
            }
        }

        // Filter out very short/generic tags
        let filteredTags = tags.filter { $0.count >= 2 }
        guard !filteredTags.isEmpty else { return }

        let tagArray = Array(filteredTags)
        await memoryStore.patchTags(groupId: groupIdLR, newTags: tagArray)
        await memoryStore.patchTags(groupId: groupIdRL, newTags: tagArray)
        NHLogger.brain.info("[NPCBrainManager] Patched \(tagArray.count) tags for \(leftId)↔\(rightId)")
    }

    // MARK: - Hack Mechanic

    /// Fetch all partner memories from API for hack. Falls back to local cache.
    func hackNPC(_ npcId: String) async -> [String: [TimestampedMemory]]? {
        guard let brain = brains[npcId] else {
            NHLogger.brain.debug("[NPCBrainManager] Hack failed: no brain for \(npcId)")
            return nil
        }
        let memories = await brain.fetchAllPartnerMemories()
        NHLogger.brain.info("[NPCBrainManager] Hack: \(npcId) has \(memories.count) partner memory groups")
        return memories
    }

    func conversationMeta(groupId: String) async -> ConversationMetaData? {
        await memoryStore.fetchConversationMeta(groupId: groupId)
    }

    /// Fetch merged ConversationMeta tags for both directions of a conversation pair.
    nonisolated func fetchConversationTags(leftId: String, rightId: String) async -> [String] {
        let groupIdLR = "\(leftId)_about_\(rightId)"
        let groupIdRL = "\(rightId)_about_\(leftId)"

        async let metaLR = memoryStore.fetchConversationMeta(groupId: groupIdLR)
        async let metaRL = memoryStore.fetchConversationMeta(groupId: groupIdRL)

        let (lr, rl) = await (metaLR, metaRL)
        let tags = Set((lr?.tags ?? []) + (rl?.tags ?? []))
        return Array(tags).sorted()
    }

    // MARK: - Zone Assignments

    /// Returns current zone assignments for all NPCs.
    func currentZoneAssignments() -> [String: String] {
        gameState.zoneState.npcZones
    }

    // MARK: - Zone Rescheduling

    /// Reshuffle all NPC zones. Called after conversation/hack ends.
    /// `involvedNPCIds`: NPCs that just participated — they stay in place (cooldown).
    func rescheduleNPCs(roster: [NPCCharacter], involvedNPCIds: Set<String> = []) {
        gameState.zoneState.clearCooldown()
        if !involvedNPCIds.isEmpty {
            gameState.zoneState.setCooldown(npcIds: involvedNPCIds)
        }
        let beforeZones = gameState.zoneState.npcZones
        tickZones(roster: roster)
        let afterZones = gameState.zoneState.npcZones
        NHLogger.brain.info("[Resched] #\(self.gameState.zoneState.scheduleCount) \(afterZones.sorted(by: { $0.key < $1.key }).map { "\($0.key)@\($0.value)" }.joined(separator: ", "))")
        let moved = beforeZones.filter { afterZones[$0.key] != $0.value }
        if !moved.isEmpty {
            NHLogger.brain.info("[Resched] Moved: \(moved.map { "\($0.key): \($0.value)→\(afterZones[$0.key] ?? "?")" }.joined(separator: ", "))")
        }
        generateObservations(roster: roster)
    }

    // MARK: - Observations

    /// For each zone with 2+ NPCs, generate observation memories (rate-limited per NPC).
    private func generateObservations(roster: [NPCCharacter]) {
        let rosterById = Dictionary(uniqueKeysWithValues: roster.map { ($0.id, $0) })
        let currentCount = gameState.zoneState.scheduleCount

        var zoneOccupants: [String: [String]] = [:]
        for (npcId, zone) in gameState.zoneState.npcZones {
            zoneOccupants[zone, default: []].append(npcId)
        }

        for (zone, npcIds) in zoneOccupants where npcIds.count >= 2 {
            for observerId in npcIds {
                let lastSched = gameState.zoneState.lastObservationSchedule[observerId] ?? 0
                guard currentCount - lastSched >= 3 else { continue }

                let targets = npcIds.filter { $0 != observerId }
                guard let targetId = targets.randomElement(),
                      let observer = rosterById[observerId],
                      let target = rosterById[targetId],
                      let brain = brains[observerId] else { continue }

                gameState.zoneState.lastObservationSchedule[observerId] = currentCount

                Task {
                    let observation = await self.generateObservationText(
                        observer: observer, target: target, zone: zone,
                        observerGoal: observer.goal
                    )
                    guard let text = observation else { return }
                    await brain.storeObservation(targetId: targetId, targetName: target.localizedName, content: text)
                    NHLogger.brain.info("[NPCBrainManager] Observation: \(observerId) saw \(targetId) in \(zone)")
                }
            }
        }
    }

    /// Generate a short observation sentence using the configured AI provider.
    private nonisolated func generateObservationText(
        observer: NPCCharacter, target: NPCCharacter, zone: String,
        observerGoal: String = ""
    ) async -> String? {
        let prompt = PromptBuilder.observationPrompt(
            observerName: observer.localizedName,
            observerRole: observer.localizedRole,
            targetName: target.localizedName,
            targetRole: target.localizedRole,
            zone: zone,
            observerGoal: observer.localizedGoal
        )
        let system = LanguageManager.shared.isEnglish
            ? "You are an observation recorder. Output only one first-person observation sentence, no more than 30 words, nothing else."
            : "你是观察记录助手。只输出一句简体中文第一人称观察，不超过30个汉字，不要任何其他内容。不要使用英文。"
        return await generateWithAI(
            system: system,
            prompt: prompt,
            temperature: observer.aiTemperature
        )
    }

    // MARK: - Reflections

    private func triggerReflectionIfNeeded(npcId: String) {
        let count = gameState.zoneState.conversationCounts[npcId] ?? 0
        guard count > 0, count % 3 == 0 else { return }

        Task {
            await generateReflection(npcId: npcId)
        }
    }

    private func generateReflection(npcId: String) async {
        guard let brain = brains[npcId] else { return }
        let character = await brain.character

        let memories = await brain.recallForDialogue(partnerId: "")
        guard !memories.isEmpty else {
            NHLogger.brain.debug("[NPCBrainManager] Reflection skipped for \(npcId): no memories")
            return
        }

        let reflection = await generateReflectionText(
            npcName: character.localizedName,
            npcRole: character.localizedRole,
            memories: memories,
            temperature: character.aiTemperature
        )
        guard let text = reflection else { return }
        await brain.storeReflection(content: text)
        NHLogger.brain.info("[NPCBrainManager] Reflection stored for \(npcId)")
    }

    private nonisolated func generateReflectionText(
        npcName: String, npcRole: String, memories: [String], temperature: Double
    ) async -> String? {
        let prompt = PromptBuilder.reflectionPrompt(
            npcName: npcName,
            npcRole: npcRole,
            memories: Array(memories.prefix(5))
        )
        let system = LanguageManager.shared.isEnglish
            ? "You are a reflection assistant. Output only one first-person reflection sentence, no more than 40 words, nothing else."
            : "你是反思助手。只输出一句简体中文第一人称反思，不超过40个汉字，不要任何其他内容。不要使用英文。"
        return await generateWithAI(
            system: system,
            prompt: prompt,
            temperature: temperature
        )
    }

    // MARK: - AI Generation Helper

    /// Shared DeepSeek → Apple FoundationModels fallback logic.
    private nonisolated func generateWithAI(
        system: String, prompt: String, temperature: Double, maxTokens: Int = 120
    ) async -> String? {
        if DeepSeekConfig.isConfigured {
            do {
                let result = try await DeepSeekAPI.generate(
                    system: system, user: prompt,
                    maxTokens: maxTokens, temperature: temperature
                )
                if !result.isEmpty { return result }
            } catch {
                NHLogger.brain.error("[NPCBrainManager] DeepSeek failed: \(error)")
            }
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(model: SystemLanguageModel.default)
                let sanitized = PromptBuilder.sanitize(prompt)
                let response = try await session.respond(to: sanitized)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { return text }
            } catch {
                NHLogger.brain.error("[NPCBrainManager] Apple AI failed: \(error)")
            }
        }
        #endif
        return nil
    }
}
