import Foundation

/// Per-NPC relationship values, persisted via Codable.
struct RelationshipValues: Codable, Equatable {
    var trust: [String: Int]
    var debt: [String: Int]
    var suspicion: [String: Int]
    var pressure: Int

    init(trust: [String: Int] = [:], debt: [String: Int] = [:],
                suspicion: [String: Int] = [:], pressure: Int = 0) {
        self.trust = trust
        self.debt = debt
        self.suspicion = suspicion
        self.pressure = pressure
    }

    mutating func clamp() {
        for key in trust.keys { trust[key] = max(0, min(5, trust[key]!)) }
        for key in debt.keys { debt[key] = max(0, min(5, debt[key]!)) }
        for key in suspicion.keys { suspicion[key] = max(0, min(5, suspicion[key]!)) }
        pressure = max(0, min(5, pressure))
    }
}

/// Pure-value zone state. No @MainActor, no ObservableObject — fully testable.
struct ZoneState {

    var npcZones: [String: String] = [:]
    var relationships: [String: RelationshipValues] = [:]
    var recentPartners: [String: [String: Int]] = [:]
    var scheduleCount: Int = 0
    var pendingConversationCandidate: ConversationCandidate?
    var conversationCounts: [String: Int] = [:]
    var lastConversationPartner: [String: String] = [:]
    var lastObservationSchedule: [String: Int] = [:]
    var cooldownNPCIds: Set<String> = []

    init() {}

    // MARK: - Cooldown

    mutating func setCooldown(npcIds: Set<String>) {
        cooldownNPCIds = npcIds
    }

    mutating func clearCooldown() {
        cooldownNPCIds = []
    }

    func isCooldown(_ npcId: String) -> Bool {
        cooldownNPCIds.contains(npcId)
    }

    /// Zones occupied by cooldown NPCs — derived, not stored.
    var cooldownZoneIds: Set<String> {
        Set(cooldownNPCIds.compactMap { npcZones[$0] })
    }

    // MARK: - Zone accessors

    func currentZone(for npcId: String) -> String? {
        npcZones[npcId]
    }

    mutating func setZone(_ zone: String, for npcId: String) {
        npcZones[npcId] = zone
    }

    func npcsInZone(_ zoneId: String) -> [String] {
        npcZones.filter { $0.value == zoneId }.map(\.key).sorted()
    }

    // MARK: - Conversation recording

    mutating func recordConversation(npcId: String, partnerId: String) {
        conversationCounts[npcId, default: 0] += 1
        lastConversationPartner[npcId] = partnerId
        recentPartners[npcId, default: [:]][partnerId] = scheduleCount
    }

    // MARK: - Relationship mutation

    mutating func applyRelationshipDeltas(
        npcId: String, partnerId: String,
        trustDelta: Int, debtDelta: Int, suspicionDelta: Int, pressureDelta: Int
    ) {
        var rel = relationships[npcId] ?? RelationshipValues()
        rel.trust[partnerId, default: 0] += trustDelta
        rel.debt[partnerId, default: 0] += debtDelta
        rel.suspicion[partnerId, default: 0] += suspicionDelta
        rel.pressure += pressureDelta
        rel.clamp()
        relationships[npcId] = rel
    }
}

// MARK: - RelationshipDataSource conformance

extension ZoneState: RelationshipDataSource {
    func trust(from npcId: String, to partnerId: String) -> Int {
        relationships[npcId]?.trust[partnerId] ?? 0
    }

    func debt(from npcId: String, to partnerId: String) -> Int {
        relationships[npcId]?.debt[partnerId] ?? 0
    }

    func suspicion(from npcId: String, to partnerId: String) -> Int {
        relationships[npcId]?.suspicion[partnerId] ?? 0
    }

    func pressure(for npcId: String) -> Int {
        relationships[npcId]?.pressure ?? 0
    }

    func recentConversationTick(from npcId: String, to partnerId: String) -> Int? {
        recentPartners[npcId]?[partnerId]
    }
}
