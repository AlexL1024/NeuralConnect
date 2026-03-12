import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable(description: "A conversation between two NPCs on a Mars-bound shuttle")
struct GeneratedConversation {
    @Guide(description: "Exactly 4 dialogue lines alternating between two speakers", .count(4))
    var lines: [GeneratedLine]
}

@available(iOS 26.0, *)
@Generable(description: "A single line of NPC dialogue")
struct GeneratedLine {
    @Guide(description: "Speaker: L for the left character, R for the right character", .anyOf(["L", "R"]))
    var speaker: String

    @Guide(description: "Dialogue text in Simplified Chinese, concise, under 20 characters")
    var text: String
}

@available(iOS 26.0, *)
@Generable(description: "A one-sentence first-person summary of a conversation")
struct GeneratedSummary {
    @Guide(description: "Summary in Simplified Chinese, first person, under 40 characters")
    var summary: String
}

#endif
