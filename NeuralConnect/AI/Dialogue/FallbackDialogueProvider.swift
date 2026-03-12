import Foundation
import os.log

struct FallbackDialogueProvider: DialogueProvider {
    let note: String

    init(note: String = "") {
        self.note = note
    }

    func generateConversation(context: ConversationContext) async -> DialogConversation {
        let displayNote = note.isEmpty ? L("AI model unavailable", "AI 对话模型不可用") : note
        NHLogger.dialogue.warning("[FallbackProvider] Returning placeholder: \(displayNote)")
        return .placeholder(
            groupId: context.group.id,
            leftName: context.group.left.displayName,
            rightName: context.group.right.displayName,
            note: displayNote
        )
    }
}
