import Foundation
import os.log

#if canImport(FoundationModels)
import FoundationModels
#endif

struct AppleFoundationModelsDialogueProvider: DialogueProvider {
    enum Status: Equatable {
        case available
        case unavailable(reason: String)
    }

    static func status() -> Status {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let availability = SystemLanguageModel.default.availability
            switch availability {
            case .available:
                return .available
            default:
                return .unavailable(reason: "\(availability)")
            }
        }
        return .unavailable(reason: "iOS < 26.0")
        #else
        return .unavailable(reason: "FoundationModels not present")
        #endif
    }

    func generateConversation(context: ConversationContext) async -> DialogConversation {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let availability = SystemLanguageModel.default.availability
            switch availability {
            case .available:
                return await generateStructured(context: context)
            default:
                NHLogger.dialogue.warning("[AppleAI] Unavailable: \(String(describing: availability))")
                break
            }
        }
        #endif

        NHLogger.dialogue.warning("[AppleAI] Falling back to placeholder")
        return .placeholder(
            groupId: context.group.id,
            leftName: context.group.left.displayName,
            rightName: context.group.right.displayName,
            note: "Fallback (Apple AI unavailable)"
        )
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateStructured(context: ConversationContext) async -> DialogConversation {
        let left = context.group.left.displayName
        let right = context.group.right.displayName

        do {
            let systemPrompt = PromptBuilder.sanitize(PromptBuilder.systemInstructions())
            let session = LanguageModelSession(model: SystemLanguageModel.default) {
                Instructions(systemPrompt)
            }

            let rc = context.relationshipContext
            let tLR = rc?.trustLR ?? 0; let tRL = rc?.trustRL ?? 0
            let sLR = rc?.suspicionLR ?? 0; let sRL = rc?.suspicionRL ?? 0
            let dLR = rc?.debtLR ?? 0; let dRL = rc?.debtRL ?? 0
            let pL = rc?.pressureL ?? 0; let pR = rc?.pressureR ?? 0
            let rawPrompt = PromptBuilder.conversationPrompt(
                left: context.leftCharacter,
                right: context.rightCharacter,
                locationName: context.group.locationName,
                leftMemories: context.leftMemories,
                rightMemories: context.rightMemories,
                leftForesights: context.leftForesights,
                rightForesights: context.rightForesights,
                leftRecentPhrases: context.leftRecentPhrases,
                rightRecentPhrases: context.rightRecentPhrases,
                conversationTags: context.conversationTags,
                intent: context.intent,
                trustLR: tLR, trustRL: tRL,
                suspicionLR: sLR, suspicionRL: sRL,
                debtLR: dLR, debtRL: dRL,
                pressureL: pL, pressureR: pR
            )
            let prompt = PromptBuilder.sanitize(rawPrompt)

            NHLogger.dialogue.debug("[AppleAI] Generating for \(left) ↔ \(right) in \(context.group.locationId)")

            let response = try await session.respond(
                to: prompt,
                generating: GeneratedConversation.self
            )
            let generated = response.content

            let lines = generated.lines.map { line in
                DialogLine(
                    speaker: line.speaker == "L" ? .left : .right,
                    text: line.text
                )
            }

            NHLogger.dialogue.info("[AppleAI] Generated \(lines.count) structured lines")
            return DialogConversation(lines: lines)
        } catch {
            NHLogger.dialogue.error("[AppleAI] Generation error: \(error)")
            return .placeholder(
                groupId: context.group.id,
                leftName: left,
                rightName: right,
                note: "Apple AI error"
            )
        }
    }
    #endif
}
