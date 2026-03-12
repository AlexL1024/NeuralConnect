import Foundation
import os.log

/// Per-NPC cognitive actor. Handles memory recall, reflection, and observation.
actor NPCBrain {

    let character: NPCCharacter
    private let memoryStore: MemoryStore

    /// Local cache: partnerId → [memories]. Appended on storeInteraction, read by hack.
    private(set) var partnerMemories: [String: [TimestampedMemory]] = [:]

    /// Ring buffer of recent dialogue lines spoken by this NPC (across all partners).
    /// Used to prevent phrase repetition — injected into prompt so LLM sees its own recent output.
    private var recentLines: [String] = []
    private let maxRecentLines = 20

    init(character: NPCCharacter, memoryStore: MemoryStore) {
        self.character = character
        self.memoryStore = memoryStore
    }

    // MARK: - Hack

    /// Fetch all partner memories from API for the hack mechanic.
    func fetchAllPartnerMemories() async -> [String: [TimestampedMemory]] {
        do {
            let result = try await memoryStore.fetchAllPartnerMemories(npcId: character.id)
            if !result.isEmpty {
                NHLogger.brain.info("[NPCBrain:\(self.character.id)] Hack fetched \(result.count) partner groups from API")
                return result
            }
        } catch {
            NHLogger.brain.error("[NPCBrain:\(self.character.id)] Hack API fetch failed: \(error)")
        }
        // Fallback to local cache
        NHLogger.brain.debug("[NPCBrain:\(self.character.id)] Hack using local cache: \(self.partnerMemories.count) groups")
        return partnerMemories
    }

    // MARK: - Recall

    /// Retrieve relevant memories about a specific partner before dialogue.
    /// Falls back to local cache if API returns empty (e.g. memory still being indexed).
    func recallForDialogue(partnerId: String) async -> [String] {
        do {
            let result = try await memoryStore.recallForPartner(npcId: character.id, partnerId: partnerId)
            if !result.isEmpty {
                NHLogger.brain.debug("[NPCBrain:\(self.character.id)] Recalled \(result.count) memories from API for partner=\(partnerId)")
                return result
            }
        } catch {
            NHLogger.brain.error("[NPCBrain:\(self.character.id)] recallForDialogue API failed: \(error)")
        }

        // Fallback: use local cache (populated by storeInteraction)
        let cached = partnerMemories[partnerId] ?? []
        if !cached.isEmpty {
            NHLogger.brain.debug("[NPCBrain:\(self.character.id)] Using \(cached.count) cached memories for partner=\(partnerId)")
        }
        return cached.map(\.text)
    }

    // MARK: - Foresight Recall

    /// Retrieve foresight memories (intentions/predictions) about a specific partner.
    func recallForesights(partnerId: String, limit: Int = 3) async -> [String] {
        do {
            let results = try await memoryStore.recallForesights(
                npcId: character.id,
                partnerId: partnerId,
                limit: limit
            )
            if !results.isEmpty {
                NHLogger.brain.debug("[NPCBrain:\(self.character.id)] Recalled \(results.count) foresights for \(partnerId)")
            }
            return results
        } catch {
            NHLogger.brain.error("[NPCBrain:\(self.character.id)] recallForesights failed: \(error)")
            return []
        }
    }

    // MARK: - Recent Lines (anti-repetition)

    /// Record dialogue lines this NPC just spoke. Call after each conversation.
    func recordLines(_ lines: [String]) {
        recentLines.append(contentsOf: lines)
        if recentLines.count > maxRecentLines {
            recentLines.removeFirst(recentLines.count - maxRecentLines)
        }
    }

    /// Extract short distinctive phrases from recent lines for dedup injection.
    func recentPhrases(limit: Int = 8) -> [String] {
        // Extract short segments (2-8 chars) that appear as quoted speech patterns
        var phrases: [String] = []
        for line in recentLines.suffix(15) {
            // Grab the whole line if short enough, otherwise extract fragments
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.count <= 15 {
                phrases.append(trimmed)
            } else {
                // Extract sentence fragments split by punctuation
                let parts = trimmed.components(separatedBy: CharacterSet(charactersIn: "，。！？、；\u{2014}\u{2026}"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count >= 2 && $0.count <= 15 }
                phrases.append(contentsOf: parts)
            }
        }
        // Deduplicate and return most recent
        var seen = Set<String>()
        var unique: [String] = []
        for p in phrases.reversed() {
            if seen.insert(p).inserted {
                unique.append(p)
            }
        }
        return Array(unique.prefix(limit))
    }

    // MARK: - Recent Partner Memories (for tag extraction)

    /// Get the most recent cached memories about a partner (for extracting keywords/entities).
    func fetchRecentPartnerMemories(partnerId: String, limit: Int = 3) -> [TimestampedMemory] {
        let cached = partnerMemories[partnerId] ?? []
        return Array(cached.suffix(limit))
    }

    // MARK: - Post-conversation

    /// Store a summary of what happened in a conversation.
    func storeInteraction(partnerId: String, partnerName: String, summary: String) async {
        // Append to local cache
        partnerMemories[partnerId, default: []].append(TimestampedMemory(text: summary, timestamp: ISO8601DateFormatter().string(from: Date())))

        do {
            try await memoryStore.storeInteraction(npc: character, partnerId: partnerId, partnerName: partnerName, summary: summary)
            NHLogger.brain.info("[NPCBrain:\(self.character.id)] Stored interaction with \(partnerId)")
        } catch {
            NHLogger.brain.error("[NPCBrain:\(self.character.id)] storeInteraction failed: \(error)")
        }
    }

    // MARK: - Reflection

    /// Generate and store a reflection (called periodically, not every conversation).
    func storeReflection(content: String) async {
        do {
            try await memoryStore.storeReflection(npc: character, content: content)
            NHLogger.brain.debug("[NPCBrain:\(self.character.id)] Stored reflection")
        } catch {
            NHLogger.brain.error("[NPCBrain:\(self.character.id)] storeReflection failed: \(error)")
        }
    }

    // MARK: - Observation

    /// Store an observation about another NPC in the same zone.
    func storeObservation(targetId: String, targetName: String, content: String) async {
        do {
            try await memoryStore.storeObservation(npc: character, targetId: targetId, targetName: targetName, content: content)
            NHLogger.brain.debug("[NPCBrain:\(self.character.id)] Stored observation about \(targetId)")
        } catch {
            NHLogger.brain.error("[NPCBrain:\(self.character.id)] storeObservation failed: \(error)")
        }
    }
}
