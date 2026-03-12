import Foundation
import Combine

@MainActor
final class GameState: ObservableObject {
    @Published var zoneState = ZoneState()

    private static let relationshipsKey = "npc_relationships"

    func initialize(roster: [NPCCharacter]) {
        zoneState = ZoneState()
        for npc in roster {
            let initialZone = npc.preferredZones.first ?? "bar"
            zoneState.npcZones[npc.id] = initialZone
            zoneState.relationships[npc.id] = RelationshipValues(pressure: npc.baselinePressure)
        }
        seedRelationships()
        loadRelationships()
    }

    private func seedRelationships() {
        zoneState.relationships["captain"]?.trust["stowaway"] = 2
        zoneState.relationships["captain"]?.suspicion["doctor"] = 2
        zoneState.relationships["stowaway"]?.suspicion["doctor"] = 2
        zoneState.relationships["attendant"]?.trust["ai_android"] = 2
        zoneState.relationships["ai_android"]?.trust["attendant"] = 1
        zoneState.relationships["gym_guy"]?.suspicion["stowaway"] = 1
    }

    // MARK: - Outcome application

    func applyOutcome(_ outcome: ConversationOutcome, npcId: String, partnerId: String) {
        zoneState.applyRelationshipDeltas(
            npcId: npcId, partnerId: partnerId,
            trustDelta: outcome.trustDelta, debtDelta: outcome.debtDelta,
            suspicionDelta: outcome.suspicionDelta, pressureDelta: outcome.pressureDelta
        )
    }

    // MARK: - Relationship Persistence

    func saveRelationships() {
        if let data = try? JSONEncoder().encode(zoneState.relationships) {
            UserDefaults.standard.set(data, forKey: Self.relationshipsKey)
        }
    }

    private func loadRelationships() {
        guard let data = UserDefaults.standard.data(forKey: Self.relationshipsKey),
              let snapshots = try? JSONDecoder().decode([String: RelationshipValues].self, from: data) else { return }
        for (npcId, snapshot) in snapshots {
            guard zoneState.relationships[npcId] != nil else { continue }
            zoneState.relationships[npcId] = snapshot
        }
    }

    static func clearRelationships() {
        UserDefaults.standard.removeObject(forKey: relationshipsKey)
    }
}
