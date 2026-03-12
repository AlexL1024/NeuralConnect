import Foundation

struct DialogLine: Identifiable, Equatable {
    enum Speaker: Equatable {
        case left
        case right
    }

    let id: UUID
    let speaker: Speaker
    let text: String

    init(id: UUID = UUID(), speaker: Speaker, text: String) {
        self.id = id
        self.speaker = speaker
        self.text = text
    }
}

struct DialogConversation: Equatable {
    let lines: [DialogLine]
}

extension DialogConversation {
    static func loading(groupId: String, leftName: String, rightName: String) -> DialogConversation {
        DialogConversation(lines: [
            DialogLine(speaker: .left, text: L("...", "……")),
        ])
    }

    static func placeholder(groupId: String, leftName: String, rightName: String, note: String? = nil) -> DialogConversation {
        DialogConversation(lines: [
            DialogLine(speaker: .left, text: L("(Signal lost)", "（信号不稳定）")),
        ])
    }
}
