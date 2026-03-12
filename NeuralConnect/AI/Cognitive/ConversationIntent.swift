import Foundation

enum InteractionMode: String {
    case askHelp
    case exchange
    case repay
    case casual
    case probe
    case avoid
}

struct ConversationIntent {
    let initiatorId: String
    let responderId: String
    let mode: InteractionMode
    let whyNow: String
    let initiatorNeedTags: [String]
    let responderOfferTags: [String]
    let allowedTopics: [String]
    let forbiddenTopics: [String]
    let secretPressureActiveLeft: Bool
    let secretPressureActiveRight: Bool
}
