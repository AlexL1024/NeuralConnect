import SwiftUI
import EverMemOSKit

#if canImport(FoundationModels)
import FoundationModels
#endif

struct HackOverlayView: View {
    let npcId: String
    let npcName: String
    @Binding var playerInvestigation: [String: [TimestampedMemory]]
    let hackAction: () async -> [String: [TimestampedMemory]]?
    let fetchConversationMetaAction: ((String) async -> ConversationMetaData?)?
    let onDismiss: () -> Void

    @State private var phase: HackPhase = .connecting
    @State private var memories: [String: [TimestampedMemory]] = [:]
    @State private var selectedPartner: String?
    @State private var glitchVisible = true
    @State private var secretScore: Int = 0

    private var npcCharacter: NPCCharacter? {
        NPCRoster.character(id: npcId) ?? NPCRoster.all.first { $0.localizedName == npcName }
    }

    private enum HackPhase {
        case connecting, scanning, extracting, results
    }

    /// Sorted partner IDs for stable tab order.
    private var sortedPartnerIds: [String] {
        memories.keys.sorted()
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    // Header
                    if phase != .results {
                        Text("NEURAL CONNECT")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }

                    switch phase {
                    case .connecting:
                        phaseView(label: L("Linking to \(npcName)...", "正在连接 \(npcName)..."), icon: "antenna.radiowaves.left.and.right")
                    case .scanning:
                        phaseView(label: L("Reading neural patterns...", "读取神经信号..."), icon: "brain")
                    case .extracting:
                        phaseView(label: L("Syncing memory data...", "同步记忆数据..."), icon: "arrow.down.doc")
                    case .results:
                        resultsView(geometry: geometry)
                    }

                    if phase == .results {
                        Button(action: onDismiss) {
                            Text(L("END CONNECT", "结束连接"))
                                .font(.system(size: 14, weight: .bold))
                                .frame(minWidth: 120)
                        }
                        .buttonStyle(.capsuleMaterial())
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(width: phase == .results ? geometry.size.width * 0.88 : geometry.size.width * 2 / 3,
                       height: geometry.size.height * 0.75)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.cyan, lineWidth: phase == .results ? 3 : 1)
                )
            }
        }
        .transition(.opacity)
        .task { await runHack() }
    }

    // MARK: - Phase views

    private func phaseView(label: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.cyan)
                .symbolEffect(.variableColor.iterative, isActive: true)

            Text(label)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(.cyan.opacity(glitchVisible ? 1.0 : 0.3))
                .animation(.easeInOut(duration: 0.15).repeatForever(autoreverses: true), value: glitchVisible)
                .onAppear { glitchVisible.toggle() }

            ProgressView()
                .tint(.cyan)
                .scaleEffect(0.8)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Results with tabs

    @ViewBuilder
    private func resultsView(geometry: GeometryProxy) -> some View {
        if memories.isEmpty {
            Text(L("No memories", "暂无记忆"))
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.vertical, 12)
        } else {
            HStack(alignment: .center, spacing: 16) {
                // Left: profile image + name
                let character = npcCharacter
                let npcColor = character.flatMap { Color(hex: $0.dotColorHex) } ?? .cyan
                VStack(spacing: 8) {
                        if let imageName = character?.profileImage,
                           let uiImage = UIImage(named: imageName) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(npcColor.opacity(0.5), lineWidth: 1)
                                )
                        }
                        Text(npcName)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan)

                        // Secret exposure bar
                        if secretScore > 0 {
                            VStack(spacing: 2) {
                                GeometryReader { barGeo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.white.opacity(0.1))
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(secretScore >= 7 ? Color.red : npcColor)
                                            .frame(width: barGeo.size.width * CGFloat(secretScore) / 10.0)
                                    }
                                }
                                .frame(height: 6)
                                Text(L("Exposure: \(secretScore)/10", "暴露度: \(secretScore)/10"))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                }
                .frame(width: 100)

                // Right: timeline
                VStack(spacing: 4) {
                    tabBar()
                    let partnerId = selectedPartner ?? sortedPartnerIds.first ?? ""
                    let items = memories[partnerId] ?? []
                    ScrollView {
                        MemoryTimelineView(items: items)
                            .padding(.vertical, 4)
                    }
                    .frame(maxHeight: geometry.size.height * 0.45)
                }
            }
        }
    }

    // MARK: - Tab bar

    private func tabBar() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sortedPartnerIds, id: \.self) { partnerId in
                    let character = NPCRoster.character(id: partnerId)
                    let name = character?.localizedName ?? partnerId
                    let color = character.flatMap { Color(hex: $0.dotColorHex) } ?? .cyan
                    let isSelected = (selectedPartner ?? sortedPartnerIds.first) == partnerId
                    let count = memories[partnerId]?.count ?? 0

                    Button {
                        selectedPartner = partnerId
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color)
                                .frame(width: 6, height: 6)
                            Text("\(name)(\(count))")
                                .font(.system(size: 12, weight: isSelected ? .bold : .regular, design: .monospaced))
                        }
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            isSelected
                                ? color.opacity(0.25)
                                : Color.white.opacity(0.05),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().stroke(isSelected ? color.opacity(0.6) : .clear, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Hack sequence

    private func runHack() async {
        // Phase 1: connecting (~1s)
        try? await Task.sleep(for: .seconds(1.0))

        // Phase 2: scanning — actual data fetch
        phase = .scanning
        let result = await hackAction()

        // Phase 3: extracting (~1s)
        phase = .extracting
        try? await Task.sleep(for: .seconds(1.0))

        // Phase 4: results
        memories = result ?? [:]
        selectedPartner = sortedPartnerIds.first
        phase = .results

        // Merge into player's accumulated investigation board
        if let result {
            for (partnerId, mems) in result {
                // Key by "npcId_about_partnerId" to keep NPC source info
                let key = "\(npcId)_about_\(partnerId)"
                let existingIds = Set((playerInvestigation[key] ?? []).map(\.id))
                let newMems = mems.filter { !existingIds.contains($0.id) }
                playerInvestigation[key, default: []].append(contentsOf: newMems)
            }
        }

        // Score secret proximity in background
        Task {
            let scorer = SecretScorer()
            let allTexts = memories.values.flatMap { $0.map(\.text) }
            guard let npc = npcCharacter, !allTexts.isEmpty else { return }
            let score = await scorer.scoreSecretProximity(
                npcName: npc.localizedName,
                secret: npc.localizedSecret,
                memories: allTexts
            )
            await MainActor.run {
                self.secretScore = score
            }
        }
    }
}

// MARK: - Entity Graph View (Knowledge Graph)

private struct EntityNode: Identifiable {
    let id: String           // entity name (dedup key)
    let label: String        // display name
    let type: EntityType
    var memoryIds: Set<String> = []  // associated memory IDs
    var secretScore: Int = 0
    var degree: Int { memoryIds.count }
}

private enum EntityType {
    case npc
    case concept
    case location
    case tag

    var color: Color {
        switch self {
        case .npc:      return .cyan
        case .concept:  return .purple
        case .location: return .green
        case .tag:      return .orange
        }
    }
}

private struct EntityEdge: Identifiable, Hashable {
    let a: String
    let b: String
    let weight: Int  // shared memory count

    var id: String { a < b ? "\(a)|\(b)" : "\(b)|\(a)" }

    nonisolated var strength: Double {
        min(1.0, log(Double(weight) + 1.0) / 2.0)
    }
}

private struct EntityGraphView: View {
    /// Keys are "npcId_about_partnerId" for player investigation board
    let memories: [String: [TimestampedMemory]]
    let fetchConversationMetaAction: ((String) async -> ConversationMetaData?)?
    let secretScore: Int

    @State private var nodes: [EntityNode] = []
    @State private var edges: [EntityEdge] = []
    @State private var positions: [String: CGPoint] = [:]
    @State private var activeNodeDragId: String?
    @State private var dragStartNormalized: CGPoint = .init(x: 0.5, y: 0.5)
    @State private var isReady = false
    @State private var selectedNode: EntityNode?
    @State private var selectedEdge: EntityEdge?

    // All memories flat for detail sheets
    private var allMemories: [TimestampedMemory] {
        memories.values.flatMap { $0 }
    }

    // Known NPC IDs for type classification
    private static let npcIds = Set(NPCRoster.all.map(\.id))
    private static let npcNameToId: [String: String] = {
        var map: [String: String] = [:]
        for npc in NPCRoster.all {
            map[npc.id] = npc.id
            map[npc.localizedName] = npc.id
            map[npc.name] = npc.id
            // Also add EN names if different
            if npc.nameEN != npc.name { map[npc.nameEN] = npc.id }
        }
        return map
    }()

    private static let locationKeywords: [String] = [
        "酒吧", "bar", "生态穹顶", "ecology", "dome", "观景台", "observation",
        "教堂", "chapel", "诊所", "clinic", "公共区", "commons", "能源室", "engine",
        "船长室", "bridge", "医务室", "medbay", "穿梭机", "shuttle", "走廊", "corridor",
        "自助餐", "cafeteria", "实验室", "lab"
    ]


    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
                    )

                if nodes.count < 2 {
                    Text(L("Connect more NPCs to build your clue board.", "连接更多角色来构建你的线索板。"))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 12)
                } else {
                    graphCanvas(size: geo.size)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { resetLayout() }
                }
            }
            .sheet(item: $selectedNode) { node in
                EntityDetailSheet(node: node, allMemories: allMemories)
            }
            .sheet(item: $selectedEdge) { edge in
                EdgeDetailSheet(edge: edge, nodes: nodes, allMemories: allMemories)
            }
        }
        .task {
            await buildGraph()
        }
    }

    @ViewBuilder
    private func graphCanvas(size: CGSize) -> some View {
        let currentPositions = mergedPositions()
        // Promoted nodes: non-NPC nodes connected to 2+ NPC nodes (clue = emergent)
        let promotedIds = promotedClueIds()

        ZStack {
            // Edges
            Canvas { ctx, canvasSize in
                guard canvasSize.width > 0, canvasSize.height > 0 else { return }
                for e in edges {
                    guard let p1 = currentPositions[e.a], let p2 = currentPositions[e.b] else { continue }
                    let a = toPoint(p1, size: canvasSize)
                    let b = toPoint(p2, size: canvasSize)

                    var path = Path()
                    path.move(to: a)
                    path.addLine(to: b)

                    let isClueEdge = promotedIds.contains(e.a) || promotedIds.contains(e.b)
                    let edgeColor: Color = isClueEdge ? .yellow : .cyan
                    let alpha = 0.10 + 0.40 * e.strength
                    let lineW = 1.0 + 2.0 * e.strength
                    ctx.stroke(path, with: .color(edgeColor.opacity(alpha)), lineWidth: lineW)
                }
            }

            // Nodes
            ForEach(nodes) { node in
                let pos = currentPositions[node.id] ?? CGPoint(x: 0.5, y: 0.5)
                let p = toPoint(pos, size: size)
                let nodeSize = nodeRadius(for: node)
                let isPromoted = promotedIds.contains(node.id)
                let color = node.secretScore >= 7 ? Color.red : (isPromoted ? Color.yellow : node.type.color)

                ZStack {
                    if isPromoted {
                        // 线索卡片造型 — 连接 2+ NPC 的概念节点
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.yellow.opacity(0.25))
                            .frame(width: 60, height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.yellow.opacity(0.7), lineWidth: 1)
                            )
                            .shadow(color: .yellow.opacity(0.3), radius: 4)
                        Text(node.label)
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(.yellow)
                            .lineLimit(2)
                            .frame(width: 56)
                    } else {
                        // Pulse for high secret score
                        if node.secretScore >= 7 {
                            Circle()
                                .fill(Color.red.opacity(0.15))
                                .frame(width: nodeSize * 3, height: nodeSize * 3)
                                .modifier(PulseModifier())
                        }

                        Circle()
                            .fill(color.opacity(0.25))
                            .overlay(
                                Circle().stroke(color.opacity(0.75), lineWidth: node.type == .npc ? 2 : 1)
                            )
                            .frame(width: nodeSize * 2, height: nodeSize * 2)
                            .shadow(color: color.opacity(0.3), radius: 6)

                        Text(node.label)
                            .font(.system(size: max(8, min(11, 7 + CGFloat(node.degree))), weight: node.type == .npc ? .bold : .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .offset(y: nodeSize + 8)
                    }
                }
                .position(p)
                .contentShape(Circle().scale(2))
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if activeNodeDragId != node.id {
                                activeNodeDragId = node.id
                                dragStartNormalized = currentPositions[node.id] ?? pos
                            }
                            let dx = size.width > 0 ? (value.translation.width / size.width) : 0
                            let dy = size.height > 0 ? (value.translation.height / size.height) : 0
                            positions[node.id] = clamp(CGPoint(x: dragStartNormalized.x + dx, y: dragStartNormalized.y + dy))
                        }
                        .onEnded { _ in activeNodeDragId = nil }
                )
                .onTapGesture { selectedNode = node }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isReady)
    }

    /// Non-NPC nodes connected to 2+ NPC nodes — promoted to clue styling
    /// Only concept/tag nodes qualify; locations are structural noise (everyone is on the same ship)
    private func promotedClueIds() -> Set<String> {
        let npcIds = Set(nodes.filter { $0.type == .npc }.map(\.id))
        let promotable = Set(nodes.filter { $0.type == .concept || $0.type == .tag }.map(\.id))
        var npcNeighborCount: [String: Int] = [:]
        for e in edges {
            if npcIds.contains(e.a) && promotable.contains(e.b) {
                npcNeighborCount[e.b, default: 0] += 1
            } else if npcIds.contains(e.b) && promotable.contains(e.a) {
                npcNeighborCount[e.a, default: 0] += 1
            }
        }
        return Set(npcNeighborCount.filter { $0.value >= 2 }.map(\.key))
    }

    private func nodeRadius(for node: EntityNode) -> CGFloat {
        let base: CGFloat = node.type == .npc ? 10 : 7
        let degreeBonus = CGFloat(min(6, node.degree)) * 1.5
        return base + degreeBonus
    }

    private func toPoint(_ n: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: n.x * size.width, y: n.y * size.height)
    }

    private func clamp(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(0.96, max(0.04, p.x)), y: min(0.96, max(0.04, p.y)))
    }

    private func mergedPositions() -> [String: CGPoint] {
        if positions.count >= nodes.count { return positions }
        var merged = positions
        let initial = Self.initialPositions(for: nodes)
        for (k, v) in initial where merged[k] == nil { merged[k] = v }
        return merged
    }

    private func resetLayout() {
        withAnimation(.easeInOut(duration: 0.2)) {
            positions = Self.initialPositions(for: nodes)
        }
    }

    // MARK: - Graph Construction

    @MainActor
    private func buildGraph() async {
        let allMems = allMemories
        var entityMap: [String: EntityNode] = [:]

        // Helper: add or update an entity node, linking it to a memory
        func link(_ key: String, label: String, type: EntityType, memId: String) {
            if entityMap[key] == nil {
                entityMap[key] = EntityNode(id: key, label: label, type: type)
            }
            entityMap[key]?.memoryIds.insert(memId)
        }

        // 1. Create NPC nodes from all group keys (format: "npcId_about_partnerId")
        var allNpcIds: Set<String> = []
        for key in memories.keys {
            // Parse "npcId_about_partnerId" format
            if let range = key.range(of: "_about_") {
                let sourceId = String(key[key.startIndex..<range.lowerBound])
                let partnerId = String(key[range.upperBound...])
                allNpcIds.insert(sourceId)
                allNpcIds.insert(partnerId)
            }
        }
        for npcNodeId in allNpcIds {
            let name = NPCRoster.character(id: npcNodeId)?.localizedName ?? npcNodeId
            entityMap[npcNodeId] = EntityNode(id: npcNodeId, label: name, type: .npc)
        }

        // 2. Process each memory
        for mem in allMems {
            let memId = mem.id
            let text = mem.text

            // 2a. Link NPC nodes via groupId (format: "npcId_about_partnerId")
            if let gId = mem.groupId, let range = gId.range(of: "_about_") {
                let sourceId = String(gId[gId.startIndex..<range.lowerBound])
                let partnerId = String(gId[range.upperBound...])
                entityMap[sourceId]?.memoryIds.insert(memId)
                entityMap[partnerId]?.memoryIds.insert(memId)
            }

            // 2b. API-provided linkedEntities
            for entity in (mem.linkedEntities ?? []) {
                // Check if it's actually an NPC name
                if let npcId = Self.npcNameToId[entity] {
                    entityMap[npcId]?.memoryIds.insert(memId)
                } else {
                    let type = Self.classifyEntity(entity)
                    link(entity.lowercased(), label: entity, type: type, memId: memId)
                }
            }

            // 2c. API-provided keywords
            for keyword in (mem.keywords ?? []) where keyword.count >= 2 {
                if let npcId = Self.npcNameToId[keyword] {
                    entityMap[npcId]?.memoryIds.insert(memId)
                } else {
                    let type = Self.classifyEntity(keyword)
                    link(keyword.lowercased(), label: keyword, type: type, memId: memId)
                }
            }

            // 2d. API-provided participants — direct NPC linking
            for participantId in (mem.participants ?? []) {
                if entityMap[participantId] == nil {
                    let displayName = NPCRoster.character(id: participantId)?.localizedName ?? participantId
                    entityMap[participantId] = EntityNode(id: participantId, label: displayName, type: .npc)
                }
                entityMap[participantId]?.memoryIds.insert(memId)
            }

        }

        // 3. Fetch ConversationMeta tags for all group keys
        if let fetchMeta = fetchConversationMetaAction {
            for groupKey in memories.keys {
                // groupKey is already in "npcId_about_partnerId" format
                if let meta = await fetchMeta(groupKey) {
                    for tag in (meta.tags ?? []) where tag.count >= 2 {
                        let key = "tag_\(tag.lowercased())"
                        if entityMap[key] == nil {
                            entityMap[key] = EntityNode(id: key, label: tag, type: .tag)
                        }
                        let groupMems = memories[groupKey] ?? []
                        for m in groupMems { entityMap[key]?.memoryIds.insert(m.id) }
                    }
                }
            }
        }

        // 4. Filter: keep NPC nodes always; concepts/locations/tags only if they appear in 2+ memories
        var filtered = entityMap.values.filter { $0.type == .npc || $0.memoryIds.count >= 2 }
        // Cap non-NPC nodes to avoid clutter (top 25 by degree)
        let npcNodes = filtered.filter { $0.type == .npc }
        let otherNodes = filtered.filter { $0.type != .npc }
            .sorted { $0.memoryIds.count > $1.memoryIds.count }
        filtered = npcNodes + Array(otherNodes.prefix(25))
        let nodeList = filtered.sorted { $0.degree > $1.degree }

        // 5. Build edges via shared memories (inverted index)
        var memToEntities: [String: [String]] = [:]
        for node in nodeList {
            for memId in node.memoryIds {
                memToEntities[memId, default: []].append(node.id)
            }
        }

        var edgeMap: [String: Int] = [:]
        let nodeSet = Set(nodeList.map(\.id))
        for (_, entityIds) in memToEntities {
            let valid = entityIds.filter { nodeSet.contains($0) }
            for i in 0..<valid.count {
                for j in (i+1)..<valid.count {
                    let a = valid[i], b = valid[j]
                    let key = a < b ? "\(a)|\(b)" : "\(b)|\(a)"
                    edgeMap[key, default: 0] += 1
                }
            }
        }

        let edgeList = edgeMap.compactMap { key, weight -> EntityEdge? in
            let parts = key.split(separator: "|")
            guard parts.count == 2 else { return nil }
            return EntityEdge(a: String(parts[0]), b: String(parts[1]), weight: weight)
        }.sorted { $0.weight > $1.weight }

        nodes = nodeList
        edges = edgeList

        // 6. Layout
        positions = Self.initialPositions(for: nodeList)
        let initial = positions
        let nodeIds = nodeList.map(\.id)
        let edgeCopy = edgeList

        let relaxed = await Task.detached(priority: .userInitiated) {
            Self.relaxPositions(positions: initial, nodeIds: nodeIds, edges: edgeCopy)
        }.value

        positions = relaxed
        isReady = true

        // 7. Async LLM keyword extraction → concept nodes
        await extractKeywordsAndMerge(baseEntityMap: entityMap, allMems: allMems)
    }

    /// Use on-device LLM to extract keywords from memories, then merge concept nodes into the graph.
    @MainActor
    private func extractKeywordsAndMerge(baseEntityMap: [String: EntityNode], allMems: [TimestampedMemory]) async {
        let extractor = KeywordExtractor()
        // Batch all memory texts for extraction
        let memTexts: [(id: String, text: String)] = allMems.map { ($0.id, $0.text) }
        guard !memTexts.isEmpty else { return }

        let extracted = await extractor.extractKeywords(from: memTexts)
        guard !extracted.isEmpty else { return }

        // Rebuild graph with concept nodes
        var entityMap = baseEntityMap

        func link(_ key: String, label: String, type: EntityType, memId: String) {
            if entityMap[key] == nil {
                entityMap[key] = EntityNode(id: key, label: label, type: type)
            }
            entityMap[key]?.memoryIds.insert(memId)
        }

        for (memId, keywords) in extracted {
            for keyword in keywords {
                let key = keyword.lowercased()
                // Skip if it's an NPC name
                if Self.npcNameToId[keyword] != nil || Self.npcNameToId[key] != nil { continue }
                let type = Self.classifyEntity(keyword)
                link(key, label: keyword, type: type, memId: memId)
            }
        }

        // Re-filter and rebuild
        var filtered = entityMap.values.filter { $0.type == .npc || $0.memoryIds.count >= 2 }
        let npcNodes = filtered.filter { $0.type == .npc }
        let otherNodes = filtered.filter { $0.type != .npc }
            .sorted { $0.memoryIds.count > $1.memoryIds.count }
        filtered = npcNodes + Array(otherNodes.prefix(25))
        let nodeList = filtered.sorted { $0.degree > $1.degree }

        var memToEntities: [String: [String]] = [:]
        for node in nodeList {
            for memId in node.memoryIds {
                memToEntities[memId, default: []].append(node.id)
            }
        }
        var edgeMap: [String: Int] = [:]
        let nodeSet = Set(nodeList.map(\.id))
        for (_, entityIds) in memToEntities {
            let valid = entityIds.filter { nodeSet.contains($0) }
            for i in 0..<valid.count {
                for j in (i+1)..<valid.count {
                    let a = valid[i], b = valid[j]
                    let key = a < b ? "\(a)|\(b)" : "\(b)|\(a)"
                    edgeMap[key, default: 0] += 1
                }
            }
        }
        let edgeList = edgeMap.compactMap { key, weight -> EntityEdge? in
            let parts = key.split(separator: "|")
            guard parts.count == 2 else { return nil }
            return EntityEdge(a: String(parts[0]), b: String(parts[1]), weight: weight)
        }.sorted { $0.weight > $1.weight }

        // Animate new nodes in
        withAnimation(.easeInOut(duration: 0.4)) {
            nodes = nodeList
            edges = edgeList
            positions = Self.initialPositions(for: nodeList)
        }

        // Relax layout
        let initial = positions
        let nodeIds = nodeList.map(\.id)
        let relaxed = await Task.detached(priority: .userInitiated) {
            Self.relaxPositions(positions: initial, nodeIds: nodeIds, edges: edgeList)
        }.value
        withAnimation(.easeInOut(duration: 0.3)) {
            positions = relaxed
        }
    }

    private static func classifyEntity(_ name: String) -> EntityType {
        let lower = name.lowercased()
        if npcIds.contains(lower) || npcNameToId[name] != nil { return .npc }
        if locationKeywords.contains(where: { lower.contains($0) }) { return .location }
        return .concept
    }

    private static func initialPositions(for nodes: [EntityNode]) -> [String: CGPoint] {
        guard !nodes.isEmpty else { return [:] }
        var result: [String: CGPoint] = [:]
        // Place NPCs in inner ring, others in outer
        let npcNodes = nodes.filter { $0.type == .npc }
        let otherNodes = nodes.filter { $0.type != .npc }

        for (i, node) in npcNodes.enumerated() {
            let angle = (Double(i) / Double(max(1, npcNodes.count))) * Double.pi * 2.0
            let radius = 0.22
            let x = 0.5 + CGFloat(cos(angle) * radius)
            let y = 0.5 + CGFloat(sin(angle) * radius)
            result[node.id] = CGPoint(x: min(0.92, max(0.08, x)), y: min(0.92, max(0.08, y)))
        }

        for (i, node) in otherNodes.enumerated() {
            let angle = (Double(i) / Double(max(1, otherNodes.count))) * Double.pi * 2.0 + 0.3
            let radius = 0.35 + 0.06 * (Double(i % 3))
            let x = 0.5 + CGFloat(cos(angle) * radius)
            let y = 0.5 + CGFloat(sin(angle) * radius)
            result[node.id] = CGPoint(x: min(0.92, max(0.08, x)), y: min(0.92, max(0.08, y)))
        }

        return result
    }

    nonisolated private static func relaxPositions(
        positions: [String: CGPoint],
        nodeIds: [String],
        edges: [EntityEdge]
    ) -> [String: CGPoint] {
        guard nodeIds.count >= 2 else { return positions }
        var pos = positions
        var velocity: [String: CGVector] = Dictionary(uniqueKeysWithValues: nodeIds.map { ($0, .zero) })

        let steps = 100
        let repulsion: CGFloat = 0.0022
        let spring: CGFloat = 0.022
        let damping: CGFloat = 0.84

        for _ in 0..<steps {
            for i in 0..<nodeIds.count {
                for j in (i + 1)..<nodeIds.count {
                    let aId = nodeIds[i], bId = nodeIds[j]
                    guard let a = pos[aId], let b = pos[bId] else { continue }
                    let dx = a.x - b.x, dy = a.y - b.y
                    let dist2 = max(0.001, dx * dx + dy * dy)
                    let f = repulsion / dist2
                    velocity[aId, default: .zero].dx += f * dx
                    velocity[aId, default: .zero].dy += f * dy
                    velocity[bId, default: .zero].dx -= f * dx
                    velocity[bId, default: .zero].dy -= f * dy
                }
            }

            for e in edges {
                guard let a = pos[e.a], let b = pos[e.b] else { continue }
                let dx = b.x - a.x, dy = b.y - a.y
                let dist = max(0.02, sqrt(dx * dx + dy * dy))
                let desired: CGFloat = 0.16 + CGFloat(0.08 * (1.0 - e.strength))
                let k = spring * CGFloat(0.6 + 0.6 * e.strength)
                let force = (dist - desired) * k
                let fx = (dx / dist) * force, fy = (dy / dist) * force
                velocity[e.a, default: .zero].dx += fx
                velocity[e.a, default: .zero].dy += fy
                velocity[e.b, default: .zero].dx -= fx
                velocity[e.b, default: .zero].dy -= fy
            }

            for id in nodeIds {
                guard let v = velocity[id], let p = pos[id] else { continue }
                let cx = (0.5 - p.x) * 0.003, cy = (0.5 - p.y) * 0.003
                let nv = CGVector(dx: (v.dx + cx) * damping, dy: (v.dy + cy) * damping)
                velocity[id] = nv
                pos[id] = CGPoint(x: min(0.95, max(0.05, p.x + nv.dx)), y: min(0.95, max(0.05, p.y + nv.dy)))
            }

            if velocity.values.reduce(0.0, { $0 + abs($1.dx) + abs($1.dy) }) < 0.002 { break }
        }
        return pos
    }
}

private struct PulseModifier: ViewModifier {
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 1.3 : 0.9)
            .opacity(pulsing ? 0.3 : 0.6)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}

// MARK: - Entity Detail Sheet

private struct EntityDetailSheet: View {
    let node: EntityNode
    let allMemories: [TimestampedMemory]

    var relatedMemories: [TimestampedMemory] {
        allMemories.filter { node.memoryIds.contains($0.id) }
            .sorted { ($0.timestamp ?? "") > ($1.timestamp ?? "") }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(node.type.color.opacity(0.3))
                        .overlay(Circle().stroke(node.type.color.opacity(0.8), lineWidth: 1))
                        .frame(width: 14, height: 14)
                    Text(node.label)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                    Spacer()
                    Text(typeLabel)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Text(L("\(relatedMemories.count) related memories", "关联 \(relatedMemories.count) 条记忆"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Divider()

                ScrollView {
                    MemoryTimelineView(items: relatedMemories)
                        .padding(.vertical, 4)
                }
            }
            .padding(16)
            .navigationTitle(node.label)
        }
    }

    private var typeLabel: String {
        switch node.type {
        case .npc:      return L("NPC", "角色")
        case .concept:  return L("Concept", "概念")
        case .location: return L("Location", "地点")
        case .tag:      return L("Tag", "标签")
        }
    }
}

// MARK: - Edge Detail Sheet

private struct EdgeDetailSheet: View {
    let edge: EntityEdge
    let nodes: [EntityNode]
    let allMemories: [TimestampedMemory]

    private var nodeA: EntityNode? { nodes.first { $0.id == edge.a } }
    private var nodeB: EntityNode? { nodes.first { $0.id == edge.b } }

    private var sharedMemories: [TimestampedMemory] {
        guard let a = nodeA, let b = nodeB else { return [] }
        let shared = a.memoryIds.intersection(b.memoryIds)
        return allMemories.filter { shared.contains($0.id) }
            .sorted { ($0.timestamp ?? "") > ($1.timestamp ?? "") }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle().fill((nodeA?.type.color ?? .cyan).opacity(0.3))
                        .overlay(Circle().stroke((nodeA?.type.color ?? .cyan).opacity(0.8), lineWidth: 1))
                        .frame(width: 12, height: 12)
                    Text(nodeA?.label ?? edge.a)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    Text("↔").foregroundStyle(.secondary)
                    Text(nodeB?.label ?? edge.b)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    Circle().fill((nodeB?.type.color ?? .cyan).opacity(0.3))
                        .overlay(Circle().stroke((nodeB?.type.color ?? .cyan).opacity(0.8), lineWidth: 1))
                        .frame(width: 12, height: 12)
                    Spacer()
                }

                Text(L("\(sharedMemories.count) shared memories", "共享 \(sharedMemories.count) 条记忆"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Divider()

                ScrollView {
                    MemoryTimelineView(items: sharedMemories)
                        .padding(.vertical, 4)
                }
            }
            .padding(16)
            .navigationTitle(L("Connection", "连接"))
        }
    }
}

private struct MemoryDetailSheet: View {
    let memory: TimestampedMemory
    let tint: Color

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(memory.text)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        detailRow(L("Timestamp", "时间"), memory.timestamp)
                        detailRow("id", memory.rawId)
                        detailRow(L("Type", "类型"), memory.memoryType)
                        detailRow("group_id", memory.groupId)
                        detailRow("group_name", memory.groupName)
                        detailRow("parent_id", memory.parentId)
                        detailRow("parent_type", memory.parentType)
                        detailRow(L("Keywords", "关键词"), list(memory.keywords))
                        detailRow(L("Entities", "实体"), list(memory.linkedEntities))
                    }
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .navigationTitle(L("Memory", "记忆"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Circle()
                        .fill(tint.opacity(0.3))
                        .overlay(Circle().stroke(tint.opacity(0.8), lineWidth: 1))
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    @ViewBuilder
    private func detailRow(_ key: String, _ value: String?) -> some View {
        if let v = value, !v.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(key)
                    .foregroundStyle(.secondary)
                Text(v)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
    }

    private func list(_ values: [String]?) -> String? {
        guard let values, !values.isEmpty else { return nil }
        return values.joined(separator: ", ")
    }
}

// MARK: - Timeline (reusable)

private struct MemoryTimelineView: View {
    let items: [TimestampedMemory]

    var body: some View {
        let currentYear = Calendar.current.component(.year, from: Date())
        var lastDateString = ""

        VStack(alignment: .leading, spacing: 0) {
            ForEach(items, id: \.id) { memory in
                let date = parseISO8601(memory.timestamp)
                let dateStr = formatDate(date, currentYear: currentYear)
                let timeStr = formatTime(date)
                let showDateHeader = dateStr != lastDateString

                let _ = { lastDateString = dateStr }()

                if showDateHeader {
                    HStack(alignment: .center, spacing: 0) {
                        Text(dateStr)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.cyan.opacity(0.7))
                            .frame(width: 52, alignment: .trailing)
                        Rectangle()
                            .fill(Color.cyan.opacity(0.3))
                            .frame(width: 1)
                            .padding(.horizontal, 8)
                        Spacer()
                    }
                    .frame(height: 20)
                }

                HStack(alignment: .top, spacing: 0) {
                    Text(timeStr)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.cyan.opacity(0.5))
                        .frame(width: 52, alignment: .trailing)

                    ZStack {
                        Rectangle()
                            .fill(Color.cyan.opacity(0.3))
                            .frame(width: 1)
                        Circle()
                            .fill(Color.cyan.opacity(0.6))
                            .frame(width: 5, height: 5)
                    }
                    .frame(width: 17)

                    Text(memory.text)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601NoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parseISO8601(_ string: String?) -> Date? {
        guard let s = string else { return nil }
        return Self.iso8601.date(from: s) ?? Self.iso8601NoFrac.date(from: s)
    }

    private func formatTime(_ date: Date?) -> String {
        guard let date else { return "--:--" }
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private func formatDate(_ date: Date?, currentYear: Int) -> String {
        guard let date else { return "--" }
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        if c.year == currentYear {
            return String(format: "%02d-%02d", c.month ?? 0, c.day ?? 0)
        }
        return String(format: "%d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - LLM Keyword Extraction

/// Extracts keywords from memory texts using on-device LLM.
private actor KeywordExtractor {

    /// Extract keywords from a batch of memories. Returns [memoryId: [keyword]].
    func extractKeywords(from memories: [(id: String, text: String)]) async -> [String: [String]] {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return [:] }

        // Batch memories into a single prompt to minimize LLM calls
        let numbered = memories.enumerated().map { "\($0.offset + 1). \($0.element.text)" }
        let batch = numbered.joined(separator: "\n")

        let isEN = await LanguageManager.shared.isEnglish
        let prompt: String
        if isEN {
            prompt = """
            Extract 2-4 key intelligence keywords from each memory below. \
            Focus on: secrets, identities, evidence, motives, technology, relationships. \
            Exclude character names and locations. \
            Reply ONLY with a JSON array of arrays, e.g. [["keyword1","keyword2"],["keyword3"]].

            \(batch)
            """
        } else {
            prompt = """
            从以下每条记忆中提取2-4个关键情报词。\
            聚焦：秘密、身份、证据、动机、技术、关系。\
            排除人名和地名。\
            只回复JSON数组的数组，如 [["关键词1","关键词2"],["关键词3"]]。

            \(batch)
            """
        }

        do {
            let session = LanguageModelSession(model: SystemLanguageModel.default)
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse JSON response
            guard let jsonStart = text.firstIndex(of: "["),
                  let jsonEnd = text.lastIndex(of: "]") else { return [:] }
            let jsonStr = String(text[jsonStart...jsonEnd])
            guard let data = jsonStr.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String]] else { return [:] }

            var result: [String: [String]] = [:]
            for (i, keywords) in parsed.enumerated() where i < memories.count {
                let filtered = keywords.filter { $0.count >= 2 }
                if !filtered.isEmpty {
                    result[memories[i].id] = filtered
                }
            }
            return result
        } catch {
            return [:]
        }
        #else
        return [:]
        #endif
    }
}
