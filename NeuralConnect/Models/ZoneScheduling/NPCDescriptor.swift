import Foundation

/// Minimal NPC descriptor for zone logic. App-layer types conform to this.
protocol NPCDescriptor {
    var id: String { get }
    var preferredZones: [String] { get }
    var agendas: [String] { get }
    var needTags: [String] { get }
    var offerTags: [String] { get }
    var avoidNPCIds: [String] { get }
}
