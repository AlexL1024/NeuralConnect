import Foundation
import os.log
import EverMemOSKit
import MemosKit

struct TimestampedMemory: Sendable, Identifiable, Hashable {
    let text: String
    let timestamp: String?  // ISO8601 from API

    // Optional metadata from EverMemOS
    let rawId: String?
    let memoryType: String?
    let groupId: String?
    let groupName: String?
    let keywords: [String]?
    let linkedEntities: [String]?
    let participants: [String]?
    let parentType: String?
    let parentId: String?

    var id: String {
        rawId ?? "\(timestamp ?? "nil")|\(groupId ?? "nil")|\(text)"
    }

    init(
        text: String,
        timestamp: String?,
        rawId: String? = nil,
        memoryType: String? = nil,
        groupId: String? = nil,
        groupName: String? = nil,
        keywords: [String]? = nil,
        linkedEntities: [String]? = nil,
        participants: [String]? = nil,
        parentType: String? = nil,
        parentId: String? = nil
    ) {
        self.text = text
        self.timestamp = timestamp
        self.rawId = rawId
        self.memoryType = memoryType
        self.groupId = groupId
        self.groupName = groupName
        self.keywords = keywords
        self.linkedEntities = linkedEntities
        self.participants = participants
        self.parentType = parentType
        self.parentId = parentId
    }
}

/// Wraps EverMemOS for NPC memory operations.
/// Per-partner groups for interactions/observations, lived group for reflections.
actor MemoryStore {

    private let service: MemosService
    private let iso = ISO8601DateFormatter()

    init(service: MemosService) {
        self.service = service
    }

    // MARK: - Conversation Meta

    func fetchConversationMeta(groupId: String) async -> ConversationMetaData? {
        do {
            return try await service.getConversationMeta(groupId: groupId)
        } catch {
            NHLogger.memory.debug("[MemoryStore] Conversation meta fetch failed: groupId=\(groupId) error=\(error)")
            return nil
        }
    }

    /// Create ConversationMeta if it doesn't exist yet (first conversation between two NPCs).
    func ensureConversationMeta(groupId: String, groupName: String, participants: [String]) async {
        // Check if already exists
        if let _ = await fetchConversationMeta(groupId: groupId) {
            NHLogger.memory.debug("[MemoryStore] ConversationMeta already exists: \(groupId)")
            return
        }

        let userDetails = Dictionary(uniqueKeysWithValues: participants.map { id in
            (id, UserDetail(fullName: id, role: "npc"))
        })
        let request = ConversationMetaCreateRequest(
            scene: "group_chat",
            sceneDesc: ["name": .string(groupName)],
            name: groupName,
            createdAt: iso.string(from: Date()),
            groupId: groupId,
            userDetails: userDetails,
            tags: []
        )
        do {
            _ = try await service.createConversationMeta(request)
            NHLogger.memory.info("[MemoryStore] Created ConversationMeta: \(groupId)")
        } catch {
            NHLogger.memory.debug("[MemoryStore] ConversationMeta create failed (may already exist): \(groupId) error=\(error)")
        }
    }

    /// Append tags to an existing ConversationMeta (merge + deduplicate, never overwrite).
    func patchTags(groupId: String, newTags: [String]) async {
        guard !newTags.isEmpty else { return }

        // Fetch existing tags to merge
        let existing = await fetchConversationMeta(groupId: groupId)
        let existingTags = Set(existing?.tags ?? [])
        let merged = existingTags.union(newTags)

        // Only patch if there are actually new tags
        guard merged.count > existingTags.count else {
            NHLogger.memory.debug("[MemoryStore] No new tags to patch for \(groupId)")
            return
        }

        let request = ConversationMetaPatchRequest(
            groupId: groupId,
            tags: Array(merged).sorted()
        )
        do {
            _ = try await service.patchConversationMeta(request)
            NHLogger.memory.info("[MemoryStore] Patched tags for \(groupId): +\(merged.count - existingTags.count) tags")
        } catch {
            NHLogger.memory.error("[MemoryStore] patchTags failed: \(groupId) error=\(error)")
        }
    }

    // MARK: - Interactions (per-partner group)

    /// Store a new interaction memory after a conversation.
    /// Sends user message + assistant acknowledgment to help EverMemOS detect conversation boundary.
    func storeInteraction(npc: NPCCharacter, partnerId: String,
                          partnerName: String, summary: String) async throws {
        let groupId = "\(npc.id)_about_\(partnerId)"
        let groupName = "\(npc.localizedName)-\(L("about", "关于"))\(partnerName)"
        NHLogger.memory.info("[MemoryStore] ✏️ WRITE interaction: \(npc.id) → \(groupId) content=\"\(summary)\"")
        let request = MemorizeRequest(
            messageId: UUID().uuidString,
            createTime: iso.string(from: Date()),
            sender: npc.id,
            content: summary,
            groupId: groupId,
            groupName: groupName,
            senderName: npc.localizedName,
            role: "user",
            referList: [partnerId],
            flush: true
        )
        do {
            let resp = try await service.memorize(request)
            print("[MemoryStore] ✅ storeInteraction OK: \(npc.id) about \(partnerId), resp=\(resp)")
        } catch {
            print("[MemoryStore] ❌ storeInteraction FAILED: \(npc.id) about \(partnerId), error=\(error)")
            throw error
        }

        // Send an assistant-role closure message to help boundary detection
        let closure = MemorizeRequest(
            messageId: UUID().uuidString,
            createTime: iso.string(from: Date()),
            sender: "system",
            content: L("[Conversation ended]", "[对话结束]"),
            groupId: groupId,
            groupName: groupName,
            senderName: "system",
            role: "assistant"
        )
        _ = try? await service.memorize(closure)
    }

    // MARK: - Observations (per-target group)

    /// Store an observation about another NPC in the same zone.
    func storeObservation(npc: NPCCharacter, targetId: String,
                          targetName: String, content: String) async throws {
        let groupId = "\(npc.id)_about_\(targetId)"
        let groupName = "\(npc.localizedName)-\(L("about", "关于"))\(targetName)"
        NHLogger.memory.info("[MemoryStore] ✏️ WRITE observation: \(npc.id) → \(groupId) content=\"\(content)\"")
        let request = MemorizeRequest(
            messageId: UUID().uuidString,
            createTime: iso.string(from: Date()),
            sender: npc.id,
            content: content,
            groupId: groupId,
            groupName: groupName,
            senderName: npc.localizedName,
            role: "user",
            flush: true
        )
        _ = try await service.memorize(request)
    }

    // MARK: - Reflections (lived group)

    /// Store a reflection memory.
    func storeReflection(npc: NPCCharacter, content: String) async throws {
        let prefix = L("[Reflection]", "[反思]")
        NHLogger.memory.info("[MemoryStore] ✏️ WRITE reflection: \(npc.id) content=\"\(prefix) \(content)\"")
        let request = MemorizeRequest(
            messageId: UUID().uuidString,
            createTime: iso.string(from: Date()),
            sender: npc.id,
            content: "\(prefix) \(content)",
            groupId: npc.livedGroupId,
            groupName: "\(npc.localizedName)-\(L("daily memories", "日常记忆"))",
            senderName: npc.localizedName,
            role: "user"
        )
        _ = try await service.memorize(request)
    }

    // MARK: - Foresight Recall

    /// Fetch foresight memories (predictions/intentions) for a specific partner.
    /// Fetches extra entries and sorts by createdAt descending to get the latest foresights.
    func recallForesights(npcId: String, partnerId: String, limit: Int = 3) async throws -> [String] {
        let groupId = "\(npcId)_about_\(partnerId)"
        NHLogger.memory.debug("[MemoryStore] Fetching foresights: npcId=\(npcId) partnerId=\(partnerId)")
        var builder = FetchMemoriesBuilder()
        builder.userId = npcId
        builder.groupIds = [groupId]
        builder.memoryType = .foresight
        builder.pageSize = 100  // Fetch extra: API ignores group_ids, need client-side filtering

        let response = try await service.fetchMemories(builder)

        // Workaround: EverMemOS Fetch API ignores group_ids filter — filter client-side.
        // Also filter out system-generated foresights (from "[Conversation ended]" closure messages).
        let filtered = response.memories.filter { memory in
            memory.groupId == groupId && !Self.isSystemClosure(memory)
        }
        if filtered.count != response.memories.count {
            NHLogger.memory.debug("[MemoryStore] ⚠️ Foresight filtered: \(response.memories.count) raw → \(filtered.count) after group+system filter for \(groupId)")
        }

        // Sort by timestamp descending so we get the newest foresights
        let sorted = filtered.sorted { a, b in
            (a.timestamp ?? "") > (b.timestamp ?? "")
        }

        var results: [String] = []
        for memory in sorted.prefix(limit) {
            let text = memory.content ?? memory.foresight ?? Self.pickText(memory)
            guard !text.isEmpty else { continue }
            results.append(text)
        }
        NHLogger.memory.info("[MemoryStore] 📖 READ foresights: \(npcId) about \(partnerId) → \(results.count) entries (from \(response.memories.count) raw, \(filtered.count) after group filter)")
        return results
    }

    // MARK: - Hack (fetch all partner memories)

    /// Fetch all memories for an NPC across all partners, grouped by partnerId.
    func fetchAllPartnerMemories(npcId: String, pageSize: Int = 100) async throws -> [String: [TimestampedMemory]] {
        NHLogger.memory.debug("[MemoryStore] Fetching all memories for \(npcId)")
        var builder = FetchMemoriesBuilder()
        builder.userId = npcId
        builder.pageSize = pageSize

        let response = try await service.fetchMemories(builder)

        // Sort by timestamp descending (newest first)
        let sorted = response.memories.sorted { a, b in
            (a.timestamp ?? "") > (b.timestamp ?? "")
        }

        var grouped: [String: [TimestampedMemory]] = [:]
        let prefix = "\(npcId)_about_"

        for memory in sorted {
            guard let gId = memory.groupId, gId.hasPrefix(prefix) else { continue }
            let partnerId = String(gId.dropFirst(prefix.count))
            let text = Self.pickText(memory)
            NHLogger.memory.debug("[MemoryStore] 📖 READ hack: \(npcId) about \(partnerId) | ts=\(memory.timestamp ?? "nil") | picked=\"\(text)\" | entities=\(memory.linkedEntities ?? []) | keywords=\(memory.keywords ?? [])")
            guard !text.isEmpty else { continue }
            grouped[partnerId, default: []].append(
                TimestampedMemory(
                    text: text,
                    timestamp: memory.timestamp,
                    rawId: memory.id,
                    memoryType: memory.memoryType,
                    groupId: memory.groupId,
                    groupName: memory.groupName,
                    keywords: memory.keywords,
                    linkedEntities: memory.linkedEntities,
                    participants: nil,
                    parentType: memory.parentType,
                    parentId: memory.parentId
                )
            )
        }

        NHLogger.memory.info("[MemoryStore] 📖 READ hack total: \(npcId) → \(grouped.count) partner groups, \(grouped.values.map(\.count).reduce(0,+)) memories")
        return grouped
    }

    // MARK: - Recall

    /// Fetch memories for a specific partner, filtered by group_ids.
    func recallForPartner(npcId: String, partnerId: String, pageSize: Int = 100) async throws -> [String] {
        let groupId = "\(npcId)_about_\(partnerId)"
        NHLogger.memory.debug("[MemoryStore] Fetching: npcId=\(npcId) partnerId=\(partnerId) pageSize=\(pageSize)")
        var builder = FetchMemoriesBuilder()
        builder.userId = npcId
        builder.groupIds = [groupId]
        builder.pageSize = pageSize

        let response = try await service.fetchMemories(builder)

        // Workaround: EverMemOS Fetch API ignores group_ids filter — filter client-side.
        // Also filter out system-generated memories (from "[Conversation ended]" closure messages).
        let filtered = response.memories.filter { memory in
            memory.groupId == groupId && !Self.isSystemClosure(memory)
        }
        if filtered.count != response.memories.count {
            NHLogger.memory.debug("[MemoryStore] ⚠️ Recall filtered: \(response.memories.count) raw → \(filtered.count) after group+system filter for \(groupId)")
        }

        // Sort by timestamp descending (newest first) so callers get most recent memories
        let sorted = filtered.sorted { a, b in
            (a.timestamp ?? "") > (b.timestamp ?? "")
        }

        var results: [String] = []
        for memory in sorted {
            let text = Self.pickText(memory)
            NHLogger.memory.debug("[MemoryStore] 📖 READ recall: \(npcId) about \(partnerId) | ts=\(memory.timestamp ?? "nil") | episode=\(memory.episode ?? "nil") | summary=\(memory.summary ?? "nil") | picked=\"\(text)\"")
            guard !text.isEmpty else { continue }
            results.append(text)
        }
        NHLogger.memory.info("[MemoryStore] 📖 READ recall total: \(npcId) about \(partnerId) → \(results.count) memories (from \(response.memories.count) raw, \(filtered.count) after group filter)")
        return results
    }

    // MARK: - Helpers

    /// Check if a memory was generated from the system closure message ("[Conversation ended]").
    private static func isSystemClosure(_ memory: FlexibleMemory) -> Bool {
        let closureMarkers = ["[Conversation ended]", "[对话结束]"]
        for field in [memory.content, memory.summary, memory.episode] {
            if let text = field, closureMarkers.contains(where: { text.contains($0) }) {
                return true
            }
        }
        return false
    }

    /// Pick best text from a memory. Prefer the candidate with the highest Chinese character ratio.
    private static func pickText(_ memory: FlexibleMemory) -> String {
        let candidates = [memory.summary, memory.episode, memory.content, memory.atomicFact]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        guard !candidates.isEmpty else { return "" }

        // Pick the candidate with the highest Chinese character ratio
        let raw = candidates.max { chineseRatio($0) < chineseRatio($1) } ?? candidates[0]
        return stripLeadingTimestamp(raw)
    }

    private static func chineseRatio(_ text: String) -> Double {
        guard !text.isEmpty else { return 0 }
        let total = text.unicodeScalars.count
        let chinese = text.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.count
        return Double(chinese) / Double(total)
    }

    /// Strip verbose timestamp prefixes added by EverMemOS server.
    /// Covers many variants:
    ///   "在2026年3月8日00:30 UTC，..."
    ///   "在2026年3月08日星期日17:43 UTC，..."
    ///   "2026年3月8日（星期日）17:36 UTC，..."
    ///   "2026年3月8日（星期日）下午5:20 UTC，..."
    ///   "On March 08, 2026 at 05:50 PM UTC, ..."
    ///   "On 2026-03-08 at 00:30 UTC, ..."
    private static func stripLeadingTimestamp(_ text: String) -> String {
        // Chinese: optional "在", date, optional weekday (星期x or （星期x）), optional time, optional UTC, comma
        let cnPattern = #"^(?:在)?\d{4}年\d{1,2}月\d{1,2}日(?:(?:星期|周)[一二三四五六日天]|（(?:星期|周)[一二三四五六日天]）)?\s*(?:(?:上午|下午|凌晨|晚上)?\s*\d{1,2}:\d{2}(?::\d{2})?)?\s*(?:UTC)?\s*[，,]\s*"#
        // English with month name: "On March 08, 2026 at 05:50 PM UTC, "
        let enNamePattern = #"^On [A-Z][a-z]+ \d{1,2},?\s*\d{4}(?:\s+at\s+\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM)?\s*(?:UTC)?)?\s*[,，]\s*"#
        // English with ISO date: "On 2026-03-08 at 00:30 UTC, "
        let enISOPattern = #"^On \d{4}-\d{1,2}-\d{1,2}(?:\s+at\s+\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM)?\s*(?:UTC)?)?\s*[,，]\s*"#

        for pattern in [cnPattern, enNamePattern, enISOPattern] {
            if let range = text.range(of: pattern, options: .regularExpression) {
                return String(text[range.upperBound...])
            }
        }
        return text
    }

}
