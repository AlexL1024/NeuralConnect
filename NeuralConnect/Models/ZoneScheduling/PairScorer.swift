import Foundation

struct ScoredPair: Sendable {
    let leftId: String
    let rightId: String
    let score: Double
}

/// Scores NPC pairs for conversation pairing. Deterministic when given a fixed RNG.
struct PairScorer {

    /// Evaluate all possible pairs and return the highest-scoring one.
    func pickBestPair<N: NPCDescriptor>(
        from npcs: [N],
        relationships: RelationshipDataSource,
        using rng: inout some RandomNumberGenerator
    ) -> ScoredPair {
        precondition(npcs.count >= 2)

        var best: ScoredPair?
        for i in 0..<npcs.count {
            for j in (i + 1)..<npcs.count {
                let score = pairScore(npcs[i], npcs[j], relationships: relationships, using: &rng)
                if best == nil || score > best!.score {
                    best = ScoredPair(leftId: npcs[i].id, rightId: npcs[j].id, score: score)
                }
            }
        }

        // If best score < 1, add randomness by shuffling
        if let b = best, b.score < 1 {
            var shuffled = npcs
            shuffled.shuffle(using: &rng)
            return ScoredPair(leftId: shuffled[0].id, rightId: shuffled[1].id, score: b.score)
        }

        return best!
    }

    /// Compute pair score. Higher = more likely to be paired.
    func pairScore<N: NPCDescriptor>(
        _ a: N, _ b: N,
        relationships: RelationshipDataSource,
        using rng: inout some RandomNumberGenerator
    ) -> Double {
        let needOfferAB = Double(overlap(a.needTags, b.offerTags))
        let needOfferBA = Double(overlap(b.needTags, a.offerTags))
        let trustAB = Double(relationships.trust(from: a.id, to: b.id))
        let trustBA = Double(relationships.trust(from: b.id, to: a.id))
        let debtAB = Double(relationships.debt(from: a.id, to: b.id))
        let debtBA = Double(relationships.debt(from: b.id, to: a.id))
        let suspAB = Double(relationships.suspicion(from: a.id, to: b.id))
        let suspBA = Double(relationships.suspicion(from: b.id, to: a.id))
        let avoid = avoidPenalty(a, b)
        let recent = recentConversationPenalty(a, b, relationships: relationships)
        let shared = sharedZoneAffinity(a, b)
        let jitter = Double.random(in: 0...1, using: &rng)

        // Trust has diminishing returns: 0-1 adds to score, 2+ subtracts aggressively.
        let trustContrib = { (t: Double) -> Double in min(t, 1.0) - max(0, t - 1.0) * 1.5 }

        // Novelty bonus: pairs that have NEVER talked get a boost
        let neverTalked = (trustAB == 0 && trustBA == 0 && suspAB == 0 && suspBA == 0) ? 3.0 : 0.0

        return 3.0 * needOfferAB
             + 2.0 * needOfferBA
             + 1.0 * trustContrib(trustAB)
             + 1.0 * trustContrib(trustBA)
             + 2.0 * debtAB
             + 2.0 * debtBA
             - 2.0 * suspAB
             - 2.0 * suspBA
             - 1.5 * avoid
             - 1.0 * recent
             + 1.0 * shared
             + neverTalked
             + jitter
    }

    // MARK: - Components

    func overlap(_ a: [String], _ b: [String]) -> Int {
        Set(a).intersection(Set(b)).count
    }

    func avoidPenalty<N: NPCDescriptor>(_ a: N, _ b: N) -> Double {
        (a.avoidNPCIds.contains(b.id) || b.avoidNPCIds.contains(a.id)) ? 1.0 : 0.0
    }

    func recentConversationPenalty<N: NPCDescriptor>(
        _ a: N, _ b: N, relationships: RelationshipDataSource
    ) -> Double {
        let tick = relationships.scheduleCount
        let lastAB = relationships.recentConversationTick(from: a.id, to: b.id)
        let lastBA = relationships.recentConversationTick(from: b.id, to: a.id)
        let recentTick = max(lastAB ?? 0, lastBA ?? 0)
        guard recentTick > 0 else { return 0 }
        let elapsed = tick - recentTick
        if elapsed <= 2 { return 100.0 }
        if elapsed <= 5 { return 15.0 }
        if elapsed <= 8 { return 5.0 }
        return 0
    }

    func sharedZoneAffinity<N: NPCDescriptor>(_ a: N, _ b: N) -> Double {
        Set(a.preferredZones).intersection(Set(b.preferredZones)).isEmpty ? 0.0 : 1.0
    }
}
