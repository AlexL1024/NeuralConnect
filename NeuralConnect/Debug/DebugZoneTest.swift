#if DEBUG
import Foundation
import os.log

private let ztLog = Logger(subsystem: "NeuralConnect", category: "ZoneTest")

/// Lightweight zone scheduling test — no AI, no memory, just ticks and validation.
/// Prints detailed zone distribution and validates constraints each tick.
@MainActor
final class DebugZoneTest {
    private let roster: [NPCCharacter]
    private var state = ZoneState()
    private let scheduler = ZoneScheduler()
    private var timer: Timer?
    private var tickCount = 0
    private let maxTicks: Int
    private var pairHistory: [(tick: Int, left: String, right: String)] = []
    private var violations: [String] = []

    init(roster: [NPCCharacter], maxTicks: Int = 30) {
        self.roster = roster
        self.maxTicks = maxTicks
    }

    func start(interval: TimeInterval = 1.5) {
        tickCount = 0
        pairHistory = []
        violations = []
        state = ZoneState()

        // Initialize zones
        for npc in roster {
            let initialZone = npc.preferredZones.first ?? "bar"
            state.npcZones[npc.id] = initialZone
            state.relationships[npc.id] = RelationshipValues(pressure: npc.baselinePressure)
        }

        // Seed some relationships for testing
        state.relationships["captain"]?.trust["stowaway"] = 2
        state.relationships["captain"]?.suspicion["doctor"] = 2
        state.relationships["stowaway"]?.suspicion["doctor"] = 2
        state.relationships["attendant"]?.trust["ai_android"] = 2

        p("╔══════════════════════════════════════════════════════╗")
        p("║         ZONE SCHEDULING TEST START                  ║")
        p("╠══════════════════════════════════════════════════════╣")
        p("║ NPCs: \(roster.map(\.id).joined(separator: ", "))")
        p("║ Zones: \(ZoneScheduler.allZoneIds.joined(separator: ", "))")
        p("║ Max ticks: \(maxTicks), interval: \(interval)s")
        p("╚══════════════════════════════════════════════════════╝")
        logDistribution("INIT")

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.runTick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        p("")
        p("╔══════════════════════════════════════════════════════╗")
        p("║                  FINAL REPORT                       ║")
        p("╠══════════════════════════════════════════════════════╣")
        p("║ Total ticks: \(tickCount)")
        p("║ Pairs formed: \(pairHistory.count)")
        p("║ Violations: \(violations.count)")

        if !violations.isEmpty {
            p("║")
            p("║ ⚠️ VIOLATIONS:")
            for v in violations {
                p("║   - \(v)")
            }
        }

        // Pair diversity report
        var pairCounts: [String: Int] = [:]
        for pair in pairHistory {
            let key = [pair.left, pair.right].sorted().joined(separator: "+")
            pairCounts[key, default: 0] += 1
        }
        if !pairCounts.isEmpty {
            p("║")
            p("║ PAIR FREQUENCY:")
            for (pair, count) in pairCounts.sorted(by: { $0.value > $1.value }) {
                p("║   \(pair): \(count)x")
            }
        }

        // Check for consecutive same pairs
        var consecutiveSame = 0
        for i in 1..<pairHistory.count {
            let prev = [pairHistory[i-1].left, pairHistory[i-1].right].sorted()
            let curr = [pairHistory[i].left, pairHistory[i].right].sorted()
            if prev == curr {
                consecutiveSame += 1
            }
        }
        p("║ Consecutive same pair: \(consecutiveSame)x")
        p("║")
        p("║ \(violations.isEmpty ? "✅ ALL CHECKS PASSED" : "❌ SOME CHECKS FAILED")")
        p("╚══════════════════════════════════════════════════════╝")
    }

    private func runTick() {
        tickCount += 1

        // Cooldown lifecycle: clear previous cooldown, set new one from last pair
        let previousCooldown = state.cooldownNPCIds
        state.clearCooldown()
        if let lastPair = pairHistory.last, lastPair.tick == tickCount - 1 {
            state.setCooldown(npcIds: Set([lastPair.left, lastPair.right]))
        }
        if !previousCooldown.isEmpty {
            p("  ❄️ Cleared cooldown: \(previousCooldown.sorted())")
        }
        if !state.cooldownNPCIds.isEmpty {
            p("  ❄️ New cooldown: \(state.cooldownNPCIds.sorted()) in zones: \(state.cooldownZoneIds.sorted())")
        }

        let beforeZones = state.npcZones

        var rng = SystemRandomNumberGenerator()
        scheduler.tick(roster: roster, state: &state, using: &rng)

        let afterZones = state.npcZones

        p("")
        p("━━━ TICK #\(tickCount) (sched=\(state.scheduleCount)) ━━━")

        // Log movements
        let moved = beforeZones.filter { afterZones[$0.key] != $0.value }
        if moved.isEmpty {
            p("  ⚠️ No NPC moved!")
        } else {
            for (npcId, oldZone) in moved.sorted(by: { $0.key < $1.key }) {
                let newZone = afterZones[npcId] ?? "?"
                p("  → \(npcId): \(oldZone) → \(newZone)")
            }
        }

        // Distribution
        logDistribution("RESULT")

        // Validate constraints
        validate()

        // Log pending pair
        if let c = state.pendingConversationCandidate {
            p("  🤝 PAIR: \(c.leftId) + \(c.rightId) → \(c.zoneId) (score: \(String(format: "%.1f", c.score)))")
            pairHistory.append((tick: tickCount, left: c.leftId, right: c.rightId))

            // Simulate conversation happened (record it so recentPartners is populated)
            state.recordConversation(npcId: c.leftId, partnerId: c.rightId)
            state.recordConversation(npcId: c.rightId, partnerId: c.leftId)
            state.pendingConversationCandidate = nil
        } else {
            p("  🚶 ALL SOLO (no pair this tick)")
        }

        // Log recent partners
        let recentPairs = state.recentPartners.flatMap { (npcId, partners) in
            partners.map { (partnerId, tick) in "\(npcId)↔\(partnerId)@t\(tick)" }
        }.sorted()
        if !recentPairs.isEmpty {
            p("  📝 Recent: \(recentPairs.joined(separator: ", "))")
        }

        if tickCount >= maxTicks {
            stop()
        }
    }

    // MARK: - Validation

    private func validate() {
        var distribution: [String: [String]] = [:]
        for (npcId, zone) in state.npcZones {
            distribution[zone, default: []].append(npcId)
        }

        // Check 1: No zone has 3+ NPCs
        for (zone, npcs) in distribution where npcs.count >= 3 {
            let msg = "TICK #\(tickCount): Zone \(zone) has \(npcs.count) NPCs: \(npcs.sorted())"
            violations.append(msg)
            p("  ❌ VIOLATION: \(msg)")
        }

        // Check 2: Count zones with 2 NPCs (should be 0 or 1, plus at most 1 cooldown zone)
        let cooldownZones = state.cooldownZoneIds
        let pairedZones = distribution.filter { $0.value.count == 2 }
        let nonCooldownPairedZones = pairedZones.filter { !cooldownZones.contains($0.key) }
        if nonCooldownPairedZones.count > 1 {
            let msg = "TICK #\(tickCount): \(nonCooldownPairedZones.count) non-cooldown zones have pairs: \(nonCooldownPairedZones.keys.sorted())"
            violations.append(msg)
            p("  ❌ VIOLATION: \(msg)")
        }

        // Check 2b: Cooldown NPCs should not be reassigned to different zones
        for npcId in state.cooldownNPCIds {
            if let zone = state.npcZones[npcId], !cooldownZones.contains(zone) {
                let msg = "TICK #\(tickCount): Cooldown NPC \(npcId) was reassigned away from cooldown zone!"
                violations.append(msg)
                p("  ❌ VIOLATION: \(msg)")
            }
        }

        // Check 2c: No non-cooldown NPC should be placed in a cooldown zone
        for (zone, npcs) in distribution where cooldownZones.contains(zone) {
            let nonCooldownInZone = npcs.filter { !state.isCooldown($0) }
            if !nonCooldownInZone.isEmpty {
                let msg = "TICK #\(tickCount): Non-cooldown NPCs \(nonCooldownInZone.sorted()) placed in cooldown zone \(zone)"
                violations.append(msg)
                p("  ❌ VIOLATION: \(msg)")
            }
        }

        // Check 3: All NPCs accounted for
        let assignedNPCs = Set(state.npcZones.keys)
        let expectedNPCs = Set(roster.map(\.id))
        if assignedNPCs != expectedNPCs {
            let missing = expectedNPCs.subtracting(assignedNPCs)
            let extra = assignedNPCs.subtracting(expectedNPCs)
            let msg = "TICK #\(tickCount): NPC mismatch! missing=\(missing) extra=\(extra)"
            violations.append(msg)
            p("  ❌ VIOLATION: \(msg)")
        }

        // Check 4: If there's a pair, verify they weren't the most recent pair
        if let c = state.pendingConversationCandidate {
            let lastA = state.recentPartners[c.leftId]?[c.rightId]
            let lastB = state.recentPartners[c.rightId]?[c.leftId]
            let lastTalk = max(lastA ?? 0, lastB ?? 0)
            if lastTalk > 0 {
                let elapsed = state.scheduleCount - lastTalk
                if elapsed <= 1 {
                    let msg = "TICK #\(tickCount): Pair \(c.leftId)+\(c.rightId) talked just \(elapsed) tick(s) ago!"
                    violations.append(msg)
                    p("  ❌ VIOLATION: \(msg)")
                } else {
                    p("  ✅ Pair last talked \(elapsed) ticks ago (ok)")
                }
            } else {
                p("  ✅ First-time pair")
            }
        }
    }

    // MARK: - Helpers

    private func logDistribution(_ label: String) {
        var distribution: [String: [String]] = [:]
        for (npcId, zone) in state.npcZones {
            distribution[zone, default: []].append(npcId)
        }

        let allZones = ZoneScheduler.allZoneIds
        var parts: [String] = []
        for zone in allZones {
            let npcs = distribution[zone] ?? []
            if npcs.isEmpty {
                parts.append("  \(zone): (empty)")
            } else {
                let marker = npcs.count == 2 ? "🤝" : "  "
                parts.append("\(marker)\(zone): \(npcs.sorted().joined(separator: ", "))")
            }
        }
        p("  [\(label)]")
        for part in parts {
            p("    \(part)")
        }
    }

    private func p(_ line: String) {
        print("[ZoneTest] \(line)")
        ztLog.notice("\(line)")
    }
}
#endif
