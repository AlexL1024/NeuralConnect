import SwiftUI

struct MiniMapView: View {
    @ObservedObject var gameState: GameState
    var playerNormalizedPosition: CGPoint

    private let mapWidth: CGFloat = 120
    private let mapHeight: CGFloat = 80

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Zone label grid (7 rows)
            VStack(spacing: 0) {
                // Row 1: Lab (center)
                zoneRow { center("LAB") }
                // Row 2: Gym (30%) + Hospital (70%)
                zoneRow { split("GYM", "HOSPITAL") }
                // Row 3: Energy Room (center)
                zoneRow { center("ENERGY") }
                // Row 4: spacer
                spacerRow
                // Row 5: Bar (30%) + Casino (70%)
                zoneRow { split("BAR", "CASINO") }
                // Row 6: spacer
                spacerRow
                // Row 7: spacer
                spacerRow
            }

            // NPC avatars placed at zone anchorUV positions
            ForEach(ShuttleLayout.zones) { zone in
                let npcsHere = gameState.zoneState.npcsInZone(zone.id)
                ForEach(Array(npcsHere.enumerated()), id: \.element) { idx, npcId in
                    let uv = zone.anchorUVs[idx % zone.anchorUVs.count]
                    miniAvatar(for: npcId, size: 16)
                        .offset(
                            x: uv.x * mapWidth - 8,
                            y: uv.y * mapHeight - 8
                        )
                }
            }

            // Player avatar
            miniAvatar(imageName: "Player2d_A", borderColor: .black, size: 20)
                .shadow(color: .white.opacity(0.8), radius: 2)
                .offset(
                    x: playerNormalizedPosition.x * mapWidth - 10,
                    y: playerNormalizedPosition.y * mapHeight - 10
                )
                .animation(.linear(duration: 0.1), value: playerNormalizedPosition.x)
                .animation(.linear(duration: 0.1), value: playerNormalizedPosition.y)
        }
        .frame(width: mapWidth, height: mapHeight)
        .background(.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Row builders

    private var rowHeight: CGFloat { mapHeight / 7 }

    private func zoneRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: mapWidth, height: rowHeight)
    }

    private var spacerRow: some View {
        Color.clear.frame(width: mapWidth, height: rowHeight)
    }

    private func center(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
    }

    private func split(_ left: String, _ right: String) -> some View {
        HStack(spacing: 0) {
            Text(left)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: mapWidth * 0.3)
            Spacer()
            Text(right)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: mapWidth * 0.4)
        }
    }

    // MARK: - Helpers

    private func miniAvatar(for npcId: String, size: CGFloat) -> some View {
        let npc = NPCRoster.character(id: npcId)
        let imgName = npc?.spriteImage ?? "Player2d_A"
        let borderColor = Color(hex: npc?.dotColorHex ?? "") ?? .gray
        return miniAvatar(imageName: imgName, borderColor: borderColor, size: size)
    }

    private func miniAvatar(imageName: String, borderColor: Color, size: CGFloat) -> some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}

// MARK: - Color hex init

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8) & 0xFF) / 255.0
        let b = Double(val & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
