import Foundation

/// Rich context passed to DialogueProvider for memory-driven conversation generation.
struct ConversationContext {
    let group: ConversationGroupDescriptor
    let leftCharacter: NPCCharacter
    let rightCharacter: NPCCharacter
    let leftMemories: [String]
    let rightMemories: [String]
    let leftForesights: [String]
    let rightForesights: [String]
    let leftRecentPhrases: [String]
    let rightRecentPhrases: [String]
    let conversationTags: [String]
    let intent: ConversationIntent?
    let relationshipContext: RelationshipContext?

    init(group: ConversationGroupDescriptor, leftCharacter: NPCCharacter, rightCharacter: NPCCharacter,
         leftMemories: [String], rightMemories: [String],
         leftForesights: [String] = [], rightForesights: [String] = [],
         leftRecentPhrases: [String] = [], rightRecentPhrases: [String] = [],
         conversationTags: [String] = [],
         intent: ConversationIntent?,
         relationshipContext: RelationshipContext? = nil) {
        self.group = group
        self.leftCharacter = leftCharacter
        self.rightCharacter = rightCharacter
        self.leftMemories = leftMemories
        self.rightMemories = rightMemories
        self.leftForesights = leftForesights
        self.rightForesights = rightForesights
        self.leftRecentPhrases = leftRecentPhrases
        self.rightRecentPhrases = rightRecentPhrases
        self.conversationTags = conversationTags
        self.intent = intent
        self.relationshipContext = relationshipContext
    }
}
