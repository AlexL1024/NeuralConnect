import Foundation
import os.log

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class DialogueService {
    private let provider: DialogueProvider
    private let brainManager: NPCBrainManager

    // Track current conversation for post-dismiss memory storage
    private var activeGroup: ConversationGroupDescriptor?
    private var activeLines: [DialogLine] = []
    private var activeIntent: ConversationIntent?

    init(provider: DialogueProvider, brainManager: NPCBrainManager) {
        self.provider = provider
        self.brainManager = brainManager
    }

    convenience init(brainManager: NPCBrainManager) {
        if DeepSeekConfig.isConfigured {
            NHLogger.dialogue.info("[DialogueService] Provider: DeepSeek")
            self.init(provider: DeepSeekDialogueProvider(), brainManager: brainManager)
            return
        }

        switch AppleFoundationModelsDialogueProvider.status() {
        case .available:
            NHLogger.dialogue.info("[DialogueService] Provider: AppleFoundationModels")
            self.init(provider: AppleFoundationModelsDialogueProvider(), brainManager: brainManager)
        case .unavailable(let reason):
            NHLogger.dialogue.info("[DialogueService] Provider: Fallback (\(reason))")
            let note = L("AI model unavailable: \(reason)", "AI 对话模型不可用: \(reason)")
            self.init(provider: FallbackDialogueProvider(note: note), brainManager: brainManager)
        }
    }

    func startConversation(
        group: ConversationGroupDescriptor,
        viewModel: DialogViewModel
    ) {
        NHLogger.dialogue.info("[DialogueService] Start: \(group.left.id) ↔ \(group.right.id) in \(group.locationId)")

        // Show loading state immediately
        let leftChar = NPCRoster.character(id: group.left.id)
        let rightChar = NPCRoster.character(id: group.right.id)
        viewModel.present(
            conversation: .loading(groupId: group.id, leftName: group.left.displayName, rightName: group.right.displayName),
            locationName: group.locationName,
            leftName: group.left.displayName,
            rightName: group.right.displayName,
            leftColorHex: leftChar?.dotColorHex ?? "",
            rightColorHex: rightChar?.dotColorHex ?? "",
            leftProfileImage: leftChar?.profileImage ?? "",
            rightProfileImage: rightChar?.profileImage ?? ""
        )

        let token = UUID()
        viewModel.setActiveToken(token)

        Task { [provider, brainManager] in
            // 1. Recall memories + foresights + recent phrases for both NPCs
            let memories = await brainManager.recallForConversation(
                leftId: group.left.id,
                rightId: group.right.id
            )
            let leftMemories = memories.left
            let rightMemories = memories.right
            let leftForesights = memories.leftForesights
            let rightForesights = memories.rightForesights
            let leftPhrases = await brainManager.recentPhrases(npcId: group.left.id)
            let rightPhrases = await brainManager.recentPhrases(npcId: group.right.id)
            NHLogger.dialogue.debug("[DialogueService] Recalled: left=\(leftMemories.count)mem+\(leftForesights.count)fore+\(leftPhrases.count)phrases right=\(rightMemories.count)mem+\(rightForesights.count)fore+\(rightPhrases.count)phrases")

            // 2. Look up full NPCCharacter data
            let leftChar = NPCRoster.character(id: group.left.id)
            let rightChar = NPCRoster.character(id: group.right.id)

            guard let left = leftChar, let right = rightChar else {
                NHLogger.dialogue.error("[DialogueService] Character not found: left=\(group.left.id) right=\(group.right.id)")
                await MainActor.run {
                    guard viewModel.isActive(token: token) else { return }
                    viewModel.replaceConversation(.placeholder(
                        groupId: group.id,
                        leftName: group.left.displayName,
                        rightName: group.right.displayName,
                        note: "Character data not found"
                    ))
                }
                return
            }

            // 3. Fetch ConversationMeta tags for topic dedup
            let tags = await brainManager.fetchConversationTags(leftId: group.left.id, rightId: group.right.id)

            // 4. Generate intent and get relationship context (rule-based, on main actor)
            let (intent, relCtx) = await MainActor.run {
                let i = brainManager.generateIntent(leftId: group.left.id, rightId: group.right.id)
                let r = brainManager.relationshipContext(leftId: group.left.id, rightId: group.right.id)
                return (i, r)
            }

            // 5. Build context and generate
            let context = ConversationContext(
                group: group,
                leftCharacter: left,
                rightCharacter: right,
                leftMemories: leftMemories,
                rightMemories: rightMemories,
                leftForesights: leftForesights,
                rightForesights: rightForesights,
                leftRecentPhrases: leftPhrases,
                rightRecentPhrases: rightPhrases,
                conversationTags: tags,
                intent: intent,
                relationshipContext: relCtx
            )

            let conversation = await provider.generateConversation(context: context)
            NHLogger.dialogue.info("[DialogueService] Generated \(conversation.lines.count) lines")

            await MainActor.run {
                guard viewModel.isActive(token: token) else {
                    NHLogger.dialogue.warning("[DialogueService] Token expired, discarding \(conversation.lines.count) lines")
                    return
                }
                self.activeGroup = group
                self.activeLines = conversation.lines
                self.activeIntent = intent
                viewModel.replaceConversation(conversation)
                NHLogger.dialogue.info("[DialogueService] UI updated with \(conversation.lines.count) lines")
            }
        }
    }

    /// Call when dialog is dismissed. Applies relationship deltas synchronously,
    /// then generates summaries and stores memories in the background.
    func onConversationEnded() {
        guard let group = activeGroup, !activeLines.isEmpty else {
            NHLogger.dialogue.debug("[DialogueService] onConversationEnded: no active group or empty lines, skipping")
            activeGroup = nil
            activeLines = []
            return
        }

        let lines = activeLines
        let leftId = group.left.id
        let rightId = group.right.id
        let leftName = group.left.displayName
        let rightName = group.right.displayName
        let intent = activeIntent

        // Clear state
        activeGroup = nil
        activeLines = []
        activeIntent = nil

        // Record spoken lines for anti-repetition (local, no async needed)
        let leftLines = lines.filter { $0.speaker == .left }.map(\.text)
        let rightLines = lines.filter { $0.speaker == .right }.map(\.text)
        Task {
            await brainManager.recordLines(npcId: leftId, lines: leftLines)
            await brainManager.recordLines(npcId: rightId, lines: rightLines)
        }

        // Apply relationship deltas synchronously (before cognitive tick)
        brainManager.applyConversationOutcomes(leftId: leftId, rightId: rightId, intent: intent)

        // Fire-and-forget: generate per-NPC summaries + store to EverMemOS
        Task {
            NHLogger.dialogue.info("[DialogueService] Generating summaries for \(leftName) ↔ \(rightName)")
            let dialogueTexts = lines.map { line in
                switch line.speaker {
                case .left: return "\(leftName): \(line.text)"
                case .right: return "\(rightName): \(line.text)"
                }
            }

            let leftTemp = NPCRoster.character(id: leftId)?.aiTemperature ?? 0.7
            let rightTemp = NPCRoster.character(id: rightId)?.aiTemperature ?? 0.7
            async let leftSummary = generateSummary(
                npcName: leftName,
                partnerName: rightName,
                dialogue: dialogueTexts,
                temperature: leftTemp
            )
            async let rightSummary = generateSummary(
                npcName: rightName,
                partnerName: leftName,
                dialogue: dialogueTexts,
                temperature: rightTemp
            )
            let (lSum, rSum) = await (leftSummary, rightSummary)
            NHLogger.dialogue.info("[DialogueService] Left summary: \(lSum)")
            NHLogger.dialogue.info("[DialogueService] Right summary: \(rSum)")

            await brainManager.storeSummaries(
                leftId: leftId, rightId: rightId,
                leftName: leftName, rightName: rightName,
                leftSummary: lSum, rightSummary: rSum
            )
            NHLogger.dialogue.info("[DialogueService] Memory stored for conversation")
        }
    }

    /// Generate a 1-sentence summary using the configured AI provider.
    private func generateSummary(npcName: String, partnerName: String, dialogue: [String], temperature: Double) async -> String {
        let prompt = PromptBuilder.summaryPrompt(npcName: npcName, partnerName: partnerName, dialogue: dialogue)

        let summarySystem = LanguageManager.shared.isEnglish
            ? "You are a memory summarization assistant. Output only one summary sentence, nothing else."
            : "你是记忆总结助手。只输出一句简体中文总结，不要任何其他内容。不要使用英文。"

        // DeepSeek path
        if DeepSeekConfig.isConfigured {
            do {
                let result = try await DeepSeekAPI.generate(
                    system: summarySystem,
                    user: prompt,
                    maxTokens: 120,
                    temperature: temperature
                )
                if !result.isEmpty { return result }
            } catch {
                NHLogger.dialogue.error("[DialogueService] DeepSeek summary failed: \(error)")
            }
        }

        // Apple FoundationModels path
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(model: SystemLanguageModel.default)
                let sanitized = PromptBuilder.sanitize(prompt)
                let response = try await session.respond(
                    to: sanitized,
                    generating: GeneratedSummary.self
                )
                let text = response.content.summary
                if !text.isEmpty { return text }
            } catch {
                NHLogger.dialogue.error("[DialogueService] Apple summary failed: \(error)")
            }
        }
        #endif

        NHLogger.dialogue.debug("[DialogueService] Using fallback summary")
        return L(
            "\(npcName) had a conversation with \(partnerName).",
            "\(npcName)和\(partnerName)进行了一次对话。"
        )
    }
}
