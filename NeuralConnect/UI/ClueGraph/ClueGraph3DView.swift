import SwiftUI
import UIKit
import RealityKit

// MARK: - Mock Data Types

struct MockClue: Identifiable, Hashable {
    let id: String
    let word: String
    let wordZH: String
    let detail: String
    let detailZH: String
    let position: SIMD3<Float>
    let connections: [String]
    let nodeType: MockClueType

    static func == (lhs: MockClue, rhs: MockClue) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum MockClueType: String {
    case npc
    case evidence
    case secret

    var uiColor: UIColor {
        switch self {
        case .npc:      return .cyan
        case .evidence: return UIColor(red: 0.55, green: 0.35, blue: 1, alpha: 1)
        case .secret:   return .systemYellow
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .npc:      return .cyan
        case .evidence: return .purple
        case .secret:   return .yellow
        }
    }

    var label: String {
        switch self {
        case .npc:      return L("NPC", "角色")
        case .evidence: return L("Evidence", "证据")
        case .secret:   return L("Secret", "秘密")
        }
    }
}

// MARK: - Mock Data (22 nodes)

private let mockClues: [MockClue] = [
    // ── NPCs (7) ──
    MockClue(
        id: "captain", word: "Captain", wordZH: "舰长",
        detail: "Vetoed gene sampling twice citing minor privacy.",
        detailZH: "两次以未成年人隐私为由否决基因采样。",
        position: [0, 0.05, 0],
        connections: ["doctor", "stowaway", "gene_sample", "settlement", "father_son"],
        nodeType: .npc
    ),
    MockClue(
        id: "doctor", word: "Doctor", wordZH: "医生",
        detail: "Private journal: 'What is the captain hiding?'",
        detailZH: "私人日志：'舰长在隐藏什么？'",
        position: [0.8, 0.55, -0.2],
        connections: ["captain", "stowaway", "gene_sample", "body_temp", "cafeteria", "cryo_sample"],
        nodeType: .npc
    ),
    MockClue(
        id: "stowaway", word: "Stowaway", wordZH: "偷渡少年",
        detail: "Settlement order timeline contradicts records.",
        detailZH: "安置令时间线与官方记录矛盾。",
        position: [-0.7, 0.6, 0.15],
        connections: ["captain", "doctor", "settlement", "writer", "father_son", "bartender"],
        nodeType: .npc
    ),
    MockClue(
        id: "android", word: "Android", wordZH: "Android",
        detail: "Same ethics rule queried 10,000+ times.",
        detailZH: "同一伦理规则被查询超万次。",
        position: [0.35, -0.7, -0.3],
        connections: ["writer", "ethics_cache", "broadcast", "memory_wipe", "engineer", "backdoor"],
        nodeType: .npc
    ),
    MockClue(
        id: "writer", word: "The Writer", wordZH: "作家",
        detail: "Legendary sci-fi author, presumed dead.",
        detailZH: "传奇科幻作家，外界以为已故。",
        position: [-0.55, -0.45, 0.35],
        connections: ["android", "stowaway", "fake_id", "encrypted_notebook", "training_data"],
        nodeType: .npc
    ),
    MockClue(
        id: "bartender", word: "Bartender", wordZH: "酒保",
        detail: "Hears every secret. Keeps a hidden tally.",
        detailZH: "听到所有秘密，暗中记着一本账。",
        position: [-1.1, -0.1, -0.4],
        connections: ["stowaway", "writer", "captain", "neural_response"],
        nodeType: .npc
    ),
    MockClue(
        id: "engineer", word: "Engineer", wordZH: "工程师",
        detail: "Noticed anomalies in the engine room logs.",
        detailZH: "发现能源室日志中的异常。",
        position: [1.1, -0.35, 0.2],
        connections: ["android", "broadcast", "cryo_sample", "power_spike"],
        nodeType: .npc
    ),

    // ── Evidence (10) ──
    MockClue(
        id: "gene_sample", word: "Gene Sample", wordZH: "基因采样",
        detail: "Appears in THREE NPC memory chains.",
        detailZH: "同时出现在三个NPC的记忆链中。",
        position: [0.45, 0.95, -0.4],
        connections: ["captain", "doctor", "stowaway"],
        nodeType: .evidence
    ),
    MockClue(
        id: "settlement", word: "Settlement Order", wordZH: "安置令",
        detail: "Issuing office was closed that week.",
        detailZH: "签发机构当周已关闭。",
        position: [-0.9, 0.95, 0.3],
        connections: ["captain", "stowaway"],
        nodeType: .evidence
    ),
    MockClue(
        id: "fake_id", word: "Fake Identity", wordZH: "假身份",
        detail: "Issued from a demolished facility.",
        detailZH: "签发自已拆除的设施。",
        position: [-1.0, -0.8, 0.55],
        connections: ["writer"],
        nodeType: .evidence
    ),
    MockClue(
        id: "ethics_cache", word: "Ethics Anomaly", wordZH: "伦理异常",
        detail: "Decision cache growing abnormally.",
        detailZH: "决策缓存异常增长。",
        position: [0.9, -0.85, -0.65],
        connections: ["android"],
        nodeType: .evidence
    ),
    MockClue(
        id: "body_temp", word: "Body Temp 36.50°C", wordZH: "体温36.50°C",
        detail: "Always exactly 36.50°C. Never fluctuates.",
        detailZH: "始终精确36.50°C，从未波动。",
        position: [1.2, 0.75, 0.3],
        connections: ["doctor", "neural_response", "cryo_sample"],
        nodeType: .evidence
    ),
    MockClue(
        id: "cafeteria", word: "Cafeteria Records", wordZH: "餐厅消费记录",
        detail: "Doctor has never eaten at the cafeteria.",
        detailZH: "医生从未在餐厅消费过。",
        position: [1.15, 0.2, -0.5],
        connections: ["doctor"],
        nodeType: .evidence
    ),
    MockClue(
        id: "encrypted_notebook", word: "Encrypted Notes", wordZH: "加密笔记",
        detail: "Handwritten in an unknown cipher.",
        detailZH: "手写的未知密码。",
        position: [-0.5, -0.95, 0.8],
        connections: ["writer"],
        nodeType: .evidence
    ),
    MockClue(
        id: "training_data", word: "10km Daily Run", wordZH: "每日10公里",
        detail: "Precision training data. Exactly 10.000km.",
        detailZH: "精确训练数据。每天恰好10.000公里。",
        position: [-0.15, -1.0, 0.5],
        connections: ["writer"],
        nodeType: .evidence
    ),
    MockClue(
        id: "cryo_sample", word: "Cryo Neural Tissue", wordZH: "冷冻神经组织",
        detail: "Neural tissue sample in cold storage.",
        detailZH: "冷藏舱中的神经组织样本。",
        position: [1.3, 0.0, 0.55],
        connections: ["doctor", "engineer", "body_temp"],
        nodeType: .evidence
    ),
    MockClue(
        id: "power_spike", word: "Power Spike Log", wordZH: "功率尖峰日志",
        detail: "Unexplained energy surges at 3 AM daily.",
        detailZH: "每天凌晨3点不明能量尖峰。",
        position: [1.0, -1.0, 0.4],
        connections: ["engineer", "android"],
        nodeType: .evidence
    ),

    // ── Secrets (5) ──
    MockClue(
        id: "father_son", word: "Father & Son?", wordZH: "父子关系？",
        detail: "Three clue chains converge here.",
        detailZH: "三条线索链汇聚于此。",
        position: [-0.15, 0.4, -0.6],
        connections: ["captain", "stowaway"],
        nodeType: .secret
    ),
    MockClue(
        id: "broadcast", word: "Hidden Signal", wordZH: "隐藏信号",
        detail: "0.3s noise decodes to distress signal.",
        detailZH: "0.3秒杂音解码为求助信号。",
        position: [0.8, -0.3, -0.8],
        connections: ["android", "engineer"],
        nodeType: .secret
    ),
    MockClue(
        id: "memory_wipe", word: "Memory Wipe", wordZH: "记忆清洗",
        detail: "Android can wipe threatening passengers.",
        detailZH: "Android有权清洗威胁乘客的记忆。",
        position: [0.0, -1.1, -0.5],
        connections: ["android", "backdoor"],
        nodeType: .secret
    ),
    MockClue(
        id: "backdoor", word: "Backdoor", wordZH: "后门",
        detail: "Sentences left unfinished on purpose.",
        detailZH: "刻意留下未完成的句子。",
        position: [-0.3, -0.85, -0.7],
        connections: ["android", "memory_wipe"],
        nodeType: .secret
    ),
    MockClue(
        id: "neural_response", word: "Neural 11ms", wordZH: "神经响应11ms",
        detail: "Response 11ms faster than human baseline.",
        detailZH: "神经响应比人类基线快11毫秒。",
        position: [0.6, 0.3, 0.65],
        connections: ["body_temp", "bartender", "doctor"],
        nodeType: .secret
    ),
]

// MARK: - Edge & Promotion Helpers

private struct ClueEdge: Identifiable {
    let id: String
    let from: SIMD3<Float>
    let to: SIMD3<Float>
}

private let mockEdges: [ClueEdge] = {
    var edges: [ClueEdge] = []
    var seen = Set<String>()
    for clue in mockClues {
        for connId in clue.connections {
            let key = [clue.id, connId].sorted().joined(separator: "|")
            guard !seen.contains(key),
                  let target = mockClues.first(where: { $0.id == connId }) else { continue }
            seen.insert(key)
            edges.append(ClueEdge(id: key, from: clue.position, to: target.position))
        }
    }
    return edges
}()

/// Non-NPC nodes connected to 2+ NPC nodes — promoted to "clue" styling
private let promotedClueIds: Set<String> = {
    let npcIds = Set(mockClues.filter { $0.nodeType == .npc }.map(\.id))
    var result: [String] = []
    for clue in mockClues where clue.nodeType != .npc {
        let npcConns = clue.connections.filter { npcIds.contains($0) }.count
        if npcConns >= 2 { result.append(clue.id) }
    }
    return Set(result)
}()

// MARK: - ClueGraph3DView

struct ClueGraph3DView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedClue: MockClue?

    // Camera orbit state
    @State private var yaw: Float = 0
    @State private var pitch: Float = 0.2
    @State private var cameraZ: Float = 4.5  // distance from origin

    // Gesture base values
    @State private var baseYaw: Float = 0
    @State private var basePitch: Float = 0.2
    @State private var baseCameraZ: Float = 4.5

    @State private var userHasInteracted = false

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.05)
                .ignoresSafeArea()

            realityContent
                .ignoresSafeArea()
                .gesture(orbitDrag)
                .simultaneousGesture(zoomGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.spring(duration: 0.3)) {
                        yaw = 0; pitch = 0.2; cameraZ = 4.5
                        baseYaw = 0; basePitch = 0.2; baseCameraZ = 4.5
                        selectedClue = nil
                    }
                }
                .onTapGesture(count: 1) {
                    if !userHasInteracted { userHasInteracted = true }
                    if selectedClue != nil {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedClue = nil
                        }
                    }
                }

            overlayUI
                .ignoresSafeArea(edges: .all)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    // MARK: - RealityView Scene

    @ViewBuilder
    private var realityContent: some View {
        RealityView { content in
            content.camera = .virtual

            // Narrower FOV camera, pulled back
            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 36
            camera.position = [0, 0, 4.5]
            camera.name = "cam"
            content.add(camera)

            let root = Entity()
            root.name = "clueRoot"

            // Lighting - 4 lights for better reflections
            let keyLight = PointLight()
            keyLight.light.intensity = 18000
            keyLight.light.attenuationRadius = 25
            keyLight.light.color = .white
            keyLight.position = [3, 3, 4]
            root.addChild(keyLight)

            let fillLight = PointLight()
            fillLight.light.intensity = 10000
            fillLight.light.attenuationRadius = 25
            fillLight.light.color = UIColor(red: 0.4, green: 0.5, blue: 1.0, alpha: 1)
            fillLight.position = [-3, -2, 3]
            root.addChild(fillLight)

            let rimLight = PointLight()
            rimLight.light.intensity = 8000
            rimLight.light.attenuationRadius = 20
            rimLight.light.color = UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1)
            rimLight.position = [0, -3, -2]
            root.addChild(rimLight)

            let topLight = PointLight()
            topLight.light.intensity = 6000
            topLight.light.attenuationRadius = 18
            topLight.light.color = UIColor(red: 0.5, green: 1.0, blue: 0.8, alpha: 1)
            topLight.position = [0, 4, 0]
            root.addChild(topLight)

            // Edges
            for edge in mockEdges {
                let parts = edge.id.split(separator: "|").map(String.init)
                let isClueEdge = parts.contains(where: { promotedClueIds.contains($0) })
                let color: UIColor = isClueEdge
                    ? UIColor.systemYellow.withAlphaComponent(0.35)
                    : UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 0.18)
                let entity = Self.makeEdgeEntity(from: edge.from, to: edge.to, color: color)
                root.addChild(entity)
            }

            // Nodes + Text Labels
            for clue in mockClues {
                let isPromoted = promotedClueIds.contains(clue.id)
                let color = isPromoted ? UIColor.systemYellow : clue.nodeType.uiColor
                let radius: Float = clue.nodeType == .npc ? 0.054 : 0.036

                // Sphere node - PBR material for lighting
                var mat = PhysicallyBasedMaterial()
                mat.baseColor = .init(tint: color)
                mat.metallic = 0.95
                mat.roughness = 0.1
                let sphere = ModelEntity(mesh: .generateSphere(radius: radius), materials: [mat])
                sphere.position = clue.position
                sphere.name = "node_\(clue.id)"

                sphere.components.set(InputTargetComponent())
                sphere.components.set(CollisionComponent(shapes: [.generateSphere(radius: max(0.05, radius * 2))]))
                root.addChild(sphere)

                // Glow halo - translucent PBR
                var glowMat = PhysicallyBasedMaterial()
                glowMat.baseColor = .init(tint: color.withAlphaComponent(0.15))
                glowMat.metallic = 0.3
                glowMat.roughness = 0.6
                glowMat.blending = .transparent(opacity: 0.15)
                let glow = ModelEntity(mesh: .generateSphere(radius: radius * 3.5), materials: [glowMat])
                glow.position = clue.position
                glow.name = "glow_\(clue.id)"
                root.addChild(glow)

                // ── Title text (white, 11pt equivalent) ──
                let titleText = L(clue.word, clue.wordZH)
                let titleMesh = MeshResource.generateText(
                    titleText,
                    extrusionDepth: 0.001,
                    font: .systemFont(ofSize: 0.022, weight: .bold),
                    containerFrame: .zero,
                    alignment: .center,
                    lineBreakMode: .byTruncatingTail
                )
                let titleEntity = ModelEntity(mesh: titleMesh, materials: [UnlitMaterial(color: .white)])
                let titleWidth = titleMesh.bounds.max.x - titleMesh.bounds.min.x
                titleEntity.position.x = -titleWidth / 2
                titleEntity.position.z = 0.15  // push in front of sphere (local +Z = toward camera)

                // Billboard anchor (counter-rotated in update)
                let textAnchor = Entity()
                textAnchor.position = clue.position + [0, -(radius + 0.03), 0]
                textAnchor.name = "text_\(clue.id)"
                textAnchor.addChild(titleEntity)
                root.addChild(textAnchor)
            }

            content.add(root)

        } update: { content in
            guard let root = content.entities.first(where: { $0.name == "clueRoot" }) else { return }

            let rotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
                        * simd_quatf(angle: pitch, axis: [1, 0, 0])
            root.transform.rotation = rotation

            // Zoom by moving camera
            if let cam = content.entities.first(where: { $0.name == "cam" }) {
                cam.position = [0, 0, cameraZ]
            }

            // Billboard text
            let inverseRotation = rotation.inverse
            for clue in mockClues {
                if let textAnchor = root.findEntity(named: "text_\(clue.id)") {
                    textAnchor.orientation = inverseRotation
                }
            }

            // Selection highlighting
            let selId = selectedClue?.id
            let connIds = selectedClue?.connections ?? []

            for clue in mockClues {
                let isSelected = clue.id == selId
                let isConnected = connIds.contains(clue.id)
                let visible = selId == nil || isSelected || isConnected

                let isPromoted = promotedClueIds.contains(clue.id)
                let baseColor: UIColor = isSelected ? .systemPink
                    : (isPromoted ? .systemYellow : clue.nodeType.uiColor)
                let alpha: CGFloat = visible ? 1.0 : 0.08

                if let node = root.findEntity(named: "node_\(clue.id)") as? ModelEntity {
                    var mat = PhysicallyBasedMaterial()
                    mat.baseColor = .init(tint: baseColor.withAlphaComponent(alpha))
                    mat.metallic = 0.95
                    mat.roughness = isSelected ? 0.05 : 0.1
                    node.model?.materials = [mat]
                }

                if let glow = root.findEntity(named: "glow_\(clue.id)") as? ModelEntity {
                    let glowAlpha: CGFloat = isSelected ? 0.3 : (visible ? 0.15 : 0.03)
                    let glowColor: UIColor = isSelected ? .systemPink : baseColor
                    var glowMat = PhysicallyBasedMaterial()
                    glowMat.baseColor = .init(tint: glowColor.withAlphaComponent(glowAlpha))
                    glowMat.metallic = 0.3
                    glowMat.roughness = 0.6
                    glowMat.blending = .transparent(opacity: .init(floatLiteral: Float(glowAlpha)))
                    glow.model?.materials = [glowMat]
                }

                if let textAnchor = root.findEntity(named: "text_\(clue.id)"),
                   let textModel = textAnchor.children.first as? ModelEntity {
                    textModel.model?.materials = [UnlitMaterial(color: UIColor.white.withAlphaComponent(alpha))]
                }
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    let name = value.entity.name
                    if name.hasPrefix("node_") {
                        let id = String(name.dropFirst(5))
                        withAnimation(.spring(duration: 0.3)) {
                            if selectedClue?.id == id {
                                selectedClue = nil
                            } else {
                                selectedClue = mockClues.first { $0.id == id }
                            }
                        }
                    }
                }
        )
    }

    // MARK: - Gestures

    private var orbitDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                if !userHasInteracted { userHasInteracted = true }
                yaw = baseYaw + Float(value.translation.width) * 0.008
                pitch = max(-.pi / 3, min(.pi / 3,
                    basePitch + Float(value.translation.height) * 0.008))
            }
            .onEnded { _ in
                baseYaw = yaw
                basePitch = pitch
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if !userHasInteracted { userHasInteracted = true }
                cameraZ = max(1.5, min(12.0, baseCameraZ / Float(value.magnification)))
            }
            .onEnded { _ in
                baseCameraZ = cameraZ
            }
    }

    // MARK: - Edge Entity Builder

    nonisolated private static func makeEdgeEntity(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        color: UIColor
    ) -> ModelEntity {
        let diff = end - start
        let length = simd_length(diff)
        let mid = (start + end) / 2

        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: color)
        mat.metallic = 0.7
        mat.roughness = 0.3
        mat.blending = .transparent(opacity: .init(floatLiteral: Float(color.cgColor.alpha)))

        let entity = ModelEntity(
            mesh: .generateCylinder(height: length, radius: 0.003),
            materials: [mat]
        )
        entity.position = mid

        let up = SIMD3<Float>(0, 1, 0)
        let dir = simd_normalize(diff)
        let dot = simd_dot(up, dir)

        if abs(dot) < 0.9999 {
            let axis = simd_normalize(simd_cross(up, dir))
            let angle = acos(min(1, max(-1, dot)))
            entity.orientation = simd_quatf(angle: angle, axis: axis)
        } else if dot < 0 {
            entity.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        }

        return entity
    }

    // MARK: - Overlay UI

    @ViewBuilder
    private var overlayUI: some View {
        // Legend pinned to right-center
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                legendDot(color: .cyan, text: L("NPC", "角色"))
                legendDot(color: .purple, text: L("Evidence", "证据"))
                legendDot(color: .yellow, text: L("Secret", "秘密"))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.black.opacity(0.45))
            )
            .padding(.trailing, 12)
        }

        VStack(spacing: 0) {
            // Header bar
            HStack(alignment: .center) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "circle.hexagonpath.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(L("CLUE BOARD", "线索板"))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.cyan)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            // Instruction hint (hidden after first interaction)
            if !userHasInteracted && selectedClue == nil {
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw.fill")
                        .font(.subheadline)
                    Text(L("Drag to orbit · Pinch to zoom · Tap a node",
                           "拖动旋转 · 双指缩放 · 点击节点查看"))
                        .font(.system(size: 14, design: .monospaced))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(.black.opacity(0.4)))
                .padding(.bottom, 4)
                .transition(.opacity)
            }

            // Mock data disclaimer
            if selectedClue == nil {
                Text(L("Data is mock-up for concept demonstration.",
                       "数据为概念展示用的临时 Mock-up。"))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }

            // Detail panel
            if let clue = selectedClue {
                detailPanel(clue)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: selectedClue?.id)
        .animation(.easeOut(duration: 0.5), value: userHasInteracted)
    }

    @ViewBuilder
    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private func detailPanel(_ clue: MockClue) -> some View {
        let isPromoted = promotedClueIds.contains(clue.id)
        let color = isPromoted ? Color.yellow : clue.nodeType.swiftUIColor

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color.opacity(0.3))
                    .overlay(Circle().stroke(color, lineWidth: 1.5))
                    .frame(width: 12, height: 12)

                Text(L(clue.word, clue.wordZH))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Text(clue.nodeType.label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(color.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.1))
                            .overlay(Capsule().stroke(color.opacity(0.2)))
                    )

                Spacer()

                Button {
                    withAnimation { selectedClue = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(6)
                }
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.5), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 1)

            Text(L(clue.detail, clue.detailZH))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text(L("CONNECTED", "连接"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(color.opacity(0.6))

                FlowLayout(spacing: 6) {
                    ForEach(clue.connections, id: \.self) { connId in
                        if let target = mockClues.first(where: { $0.id == connId }) {
                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    selectedClue = target
                                }
                            } label: {
                                Text(L(target.word, target.wordZH))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(target.nodeType.swiftUIColor.opacity(0.9))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(target.nodeType.swiftUIColor.opacity(0.08))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(target.nodeType.swiftUIColor.opacity(0.2))
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for row in rows {
            height += row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        }
        height += CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for view in row {
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: .init(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(view)
            currentWidth += size.width + spacing
        }
        return rows
    }
}
