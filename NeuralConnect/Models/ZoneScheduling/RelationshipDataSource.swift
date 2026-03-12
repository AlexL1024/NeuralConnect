import Foundation

/// Provides relationship data for pair scoring. Implemented by ZoneState.
protocol RelationshipDataSource {
    func trust(from npcId: String, to partnerId: String) -> Int
    func debt(from npcId: String, to partnerId: String) -> Int
    func suspicion(from npcId: String, to partnerId: String) -> Int
    func pressure(for npcId: String) -> Int
    func recentConversationTick(from npcId: String, to partnerId: String) -> Int?
    var scheduleCount: Int { get }
}
