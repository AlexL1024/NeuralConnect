import Foundation

enum ShuttleLayout {
    struct Zone: Identifiable {
        let id: String
        let name: String
        let nameEN: String
        let col: Int    // 0-3
        let row: Int    // 0=top, 1=bottom
        let colorHex: String

        /// NPC standing positions as UV coords (0,0)=top-left of map image, (1,1)=bottom-right.
        /// Adjust these to place NPCs at meaningful spots (sofas, desks, beds, etc.)
        let anchorUVs: [CGPoint]

        /// Zone label position in UV coords
        let labelUV: CGPoint

        var localizedName: String { L(nameEN, name) }
    }

    // UV coordinates reference TheMap.png (2356 × 1570)
    // (0,0) = top-left, (1,1) = bottom-right
    static let zones: [Zone] = [
        Zone(id: "gym",      name: "健身房", nameEN: "Gym",        col: 0, row: 0, colorHex: "#22C55E",
             anchorUVs: [
                CGPoint(x: 0.184, y: 0.363),  // px(434, 570)
                CGPoint(x: 0.314, y: 0.312),  // px(740, 490)
             ],
             labelUV: CGPoint(x: 0.15, y: 0.12)),

        Zone(id: "hospital", name: "医院",   nameEN: "Medbay",     col: 1, row: 0, colorHex: "#14B8A6",
             anchorUVs: [
                CGPoint(x: 0.679, y: 0.274),  // px(1600, 430)
                CGPoint(x: 0.722, y: 0.350),  // px(1700, 550)
             ],
             labelUV: CGPoint(x: 0.80, y: 0.10)),

        Zone(id: "lab",      name: "实验室", nameEN: "Lab",        col: 0, row: 1, colorHex: "#06B6D4",
             anchorUVs: [
                CGPoint(x: 0.490, y: 0.175),  // px(1154, 274)
                CGPoint(x: 0.550, y: 0.171),  // px(1297, 268)
             ],
             labelUV: CGPoint(x: 0.12, y: 0.40)),

        Zone(id: "energy",   name: "能源室", nameEN: "Power Room", col: 1, row: 1, colorHex: "#6366F1",
             anchorUVs: [
                CGPoint(x: 0.395, y: 0.559),  // px(931, 877)
                CGPoint(x: 0.533, y: 0.607),  // px(1255, 953)
             ],
             labelUV: CGPoint(x: 0.86, y: 0.40)),

        Zone(id: "bar",      name: "酒吧",   nameEN: "Bar",        col: 0, row: 2, colorHex: "#8B5CF6",
             anchorUVs: [
                CGPoint(x: 0.148, y: 0.707),  // px(348, 1110)
                CGPoint(x: 0.247, y: 0.718),  // px(581, 1128)
             ],
             labelUV: CGPoint(x: 0.15, y: 0.58)),

        Zone(id: "casino",   name: "赌场",   nameEN: "Casino",     col: 1, row: 2, colorHex: "#EF4444",
             anchorUVs: [
                CGPoint(x: 0.723, y: 0.640),  // px(1704, 1005)
                CGPoint(x: 0.729, y: 0.792),  // px(1717, 1244)
             ],
             labelUV: CGPoint(x: 0.82, y: 0.60)),
    ]

    static func zone(for id: String) -> Zone? {
        zones.first { $0.id == id }
    }
}
