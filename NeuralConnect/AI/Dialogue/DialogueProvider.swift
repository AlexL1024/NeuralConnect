import Foundation

protocol DialogueProvider {
    func generateConversation(context: ConversationContext) async -> DialogConversation
}
