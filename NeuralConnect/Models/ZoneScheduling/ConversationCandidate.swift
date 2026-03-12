import Foundation

/// Candidate pair selected by ZoneScheduler for the next conversation.
struct ConversationCandidate: Equatable, Sendable {
    let zoneId: String
    let leftId: String
    let rightId: String
    let score: Double
    let tick: Int
}
