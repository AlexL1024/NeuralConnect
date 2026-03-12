import Foundation

/// Per-NPC outcome of a conversation, computed from fixed rules based on InteractionMode.
struct ConversationOutcome {
    let summary: String
    let trustDelta: Int
    let debtDelta: Int
    let suspicionDelta: Int
    let pressureDelta: Int
    let fulfilledNeedTags: [String]

    /// Compute outcome for initiator based on mode.
    static func forInitiator(mode: InteractionMode, summary: String, fulfilledNeedTags: [String] = []) -> ConversationOutcome {
        switch mode {
        case .askHelp:
            return ConversationOutcome(summary: summary, trustDelta: 1, debtDelta: 1, suspicionDelta: 0, pressureDelta: -1, fulfilledNeedTags: fulfilledNeedTags)
        case .exchange:
            return ConversationOutcome(summary: summary, trustDelta: 1, debtDelta: 0, suspicionDelta: 0, pressureDelta: 0, fulfilledNeedTags: fulfilledNeedTags)
        case .repay:
            return ConversationOutcome(summary: summary, trustDelta: 1, debtDelta: -1, suspicionDelta: 0, pressureDelta: 0, fulfilledNeedTags: fulfilledNeedTags)
        case .probe:
            return ConversationOutcome(summary: summary, trustDelta: 0, debtDelta: 0, suspicionDelta: 1, pressureDelta: 0, fulfilledNeedTags: [])
        case .casual:
            return ConversationOutcome(summary: summary, trustDelta: 1, debtDelta: 0, suspicionDelta: 0, pressureDelta: 0, fulfilledNeedTags: [])
        case .avoid:
            return ConversationOutcome(summary: summary, trustDelta: -1, debtDelta: 0, suspicionDelta: 0, pressureDelta: 1, fulfilledNeedTags: [])
        }
    }

    /// Return a copy with additional suspicion delta.
    func addingSuspicion(_ extra: Int) -> ConversationOutcome {
        ConversationOutcome(
            summary: summary,
            trustDelta: trustDelta,
            debtDelta: debtDelta,
            suspicionDelta: suspicionDelta + extra,
            pressureDelta: pressureDelta,
            fulfilledNeedTags: fulfilledNeedTags
        )
    }

    /// Compute outcome for responder based on mode.
    static func forResponder(mode: InteractionMode, summary: String, fulfilledNeedTags: [String] = []) -> ConversationOutcome {
        switch mode {
        case .askHelp:
            return ConversationOutcome(summary: summary, trustDelta: 0, debtDelta: 0, suspicionDelta: 0, pressureDelta: 0, fulfilledNeedTags: [])
        case .exchange:
            return ConversationOutcome(summary: summary, trustDelta: 1, debtDelta: 0, suspicionDelta: 0, pressureDelta: 0, fulfilledNeedTags: fulfilledNeedTags)
        case .repay:
            return ConversationOutcome(summary: summary, trustDelta: 1, debtDelta: 0, suspicionDelta: 0, pressureDelta: 0, fulfilledNeedTags: [])
        case .probe:
            // Responder was probed: trust toward initiator drops, pressure rises
            return ConversationOutcome(summary: summary, trustDelta: -1, debtDelta: 0, suspicionDelta: 0, pressureDelta: 1, fulfilledNeedTags: [])
        case .casual:
            return ConversationOutcome(summary: summary, trustDelta: 1, debtDelta: 0, suspicionDelta: 0, pressureDelta: 0, fulfilledNeedTags: [])
        case .avoid:
            return ConversationOutcome(summary: summary, trustDelta: 0, debtDelta: 0, suspicionDelta: 0, pressureDelta: 0, fulfilledNeedTags: [])
        }
    }
}
