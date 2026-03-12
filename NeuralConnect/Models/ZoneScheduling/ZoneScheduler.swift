import Foundation
import os.log

private let zoneLog = Logger(subsystem: "NeuralConnect", category: "Zone")

/// Drives NPC zone assignment. No @MainActor — operates on ZoneState values.
struct ZoneScheduler {

    static let allZoneIds = ["gym", "hospital", "lab", "energy", "bar", "casino"]

    private let scorer = PairScorer()

    /// Shuffle NPC zones. One scored pair shares a zone for conversation,
    /// remaining NPCs each get a unique zone. No busy filtering.
    func tick<N: NPCDescriptor>(
        roster: [N],
        state: inout ZoneState,
        using rng: inout some RandomNumberGenerator
    ) {
        let active = roster.filter { state.currentZone(for: $0.id) != nil && !state.isCooldown($0.id) }
        guard active.count >= 2 else { return }
        let cooldownZones = state.cooldownZoneIds

        state.scheduleCount += 1

        // 1. Score all pairs and pick the best
        let bestPair = scorer.pickBestPair(from: active, relationships: state, using: &rng)

        // 2. Check if the chosen pair recently conversed — if so, all solos
        let recentA = state.recentConversationTick(from: bestPair.leftId, to: bestPair.rightId) ?? 0
        let recentB = state.recentConversationTick(from: bestPair.rightId, to: bestPair.leftId) ?? 0
        let lastTalk = max(recentA, recentB)
        let elapsed = state.scheduleCount - lastTalk
        let skipPair = lastTalk > 0 && elapsed <= 5

        if skipPair {
            zoneLog.info("[Zone] skipping pair \(bestPair.leftId)+\(bestPair.rightId) (talked \(elapsed) ticks ago), all solos")
            state.pendingConversationCandidate = nil
            assignEachToUniqueZone(active, state: &state, using: &rng)
            return
        }

        // 3. Place pair in a preference-weighted zone (excluding cooldown zones)
        let pairLeft = active.first { $0.id == bestPair.leftId }!
        let pairRight = active.first { $0.id == bestPair.rightId }!
        let pairZone = pickPairZone(pairLeft, pairRight, excluding: cooldownZones, using: &rng)
        state.setZone(pairZone, for: bestPair.leftId)
        state.setZone(pairZone, for: bestPair.rightId)
        zoneLog.info("[Zone] pair: \(bestPair.leftId)+\(bestPair.rightId)→\(pairZone) (score:\(String(format: "%.1f", bestPair.score)))")

        state.pendingConversationCandidate = ConversationCandidate(
            zoneId: pairZone,
            leftId: bestPair.leftId,
            rightId: bestPair.rightId,
            score: bestPair.score,
            tick: state.scheduleCount
        )

        // 4. Remaining NPCs each get a unique zone (excluding pair zone + cooldown zones)
        let solos = active.filter { $0.id != bestPair.leftId && $0.id != bestPair.rightId }
        var available = Set(Self.allZoneIds)
        available.remove(pairZone)
        available.subtract(cooldownZones)

        for npc in solos {
            let zone = weightedPick(npc, from: available, using: &rng)
            let old = state.currentZone(for: npc.id) ?? "?"
            state.setZone(zone, for: npc.id)
            available.remove(zone)
            zoneLog.info("[Zone] solo: \(npc.id) \(old)→\(zone)")
        }

        logDistribution(state)
    }

    // MARK: - Helpers

    /// Assign each NPC to a unique zone (all solos, no pairing).
    private func assignEachToUniqueZone<N: NPCDescriptor>(
        _ npcs: [N],
        state: inout ZoneState,
        using rng: inout some RandomNumberGenerator
    ) {
        var available = Set(Self.allZoneIds)
        available.subtract(state.cooldownZoneIds)
        for npc in npcs {
            let zone = weightedPick(npc, from: available, using: &rng)
            let old = state.currentZone(for: npc.id) ?? "?"
            state.setZone(zone, for: npc.id)
            available.remove(zone)
            zoneLog.info("[Zone] solo: \(npc.id) \(old)→\(zone)")
        }
        logDistribution(state)
    }

    /// Pick a zone for a pair, weighted by both NPCs' preferences.
    private func pickPairZone<N: NPCDescriptor>(
        _ a: N, _ b: N,
        excluding excludedZones: Set<String> = [],
        using rng: inout some RandomNumberGenerator
    ) -> String {
        let candidateZones = Self.allZoneIds.filter { !excludedZones.contains($0) }
        var weights: [(String, Double)] = []
        for zoneId in candidateZones {
            var w: Double = 1.0
            if a.preferredZones.contains(zoneId) { w += 3.0 }
            if b.preferredZones.contains(zoneId) { w += 3.0 }
            weights.append((zoneId, w))
        }
        return weightedRandom(weights, using: &rng) ?? candidateZones.randomElement(using: &rng) ?? Self.allZoneIds.randomElement(using: &rng)!
    }

    /// Pick a zone from available set, weighted by NPC preference.
    private func weightedPick<N: NPCDescriptor>(
        _ npc: N,
        from available: Set<String>,
        using rng: inout some RandomNumberGenerator
    ) -> String {
        guard !available.isEmpty else {
            return Self.allZoneIds.randomElement(using: &rng)!
        }
        let weights: [(String, Double)] = available.map { zoneId in
            let w: Double = npc.preferredZones.contains(zoneId) ? 5.0 : 1.0
            return (zoneId, w)
        }
        return weightedRandom(weights, using: &rng) ?? available.randomElement()!
    }

    private func weightedRandom(
        _ weights: [(String, Double)],
        using rng: inout some RandomNumberGenerator
    ) -> String? {
        let total = weights.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return nil }
        var roll = Double.random(in: 0..<total, using: &rng)
        for (zoneId, weight) in weights {
            roll -= weight
            if roll <= 0 { return zoneId }
        }
        return weights.last?.0
    }

    private func logDistribution(_ state: ZoneState) {
        var distribution: [String: [String]] = [:]
        for (npcId, zone) in state.npcZones {
            distribution[zone, default: []].append(npcId)
        }
        let summary = distribution.sorted(by: { $0.key < $1.key }).map { "\($0.key):\($0.value.sorted())" }.joined(separator: " | ")
        zoneLog.info("[Zone] result: \(summary)")
    }
}
