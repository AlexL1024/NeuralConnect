import Foundation
import os.log

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Uses Apple FoundationModels to score how close memories are to revealing an NPC's secret.
actor SecretScorer {

    /// Evaluate how close the given memories are to the NPC's secret.
    /// Returns 0-10. Returns 0 on failure (non-blocking).
    func scoreSecretProximity(
        npcName: String,
        secret: String,
        memories: [String]
    ) async -> Int {
        guard !memories.isEmpty else { return 0 }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let memoryList = memories.enumerated()
                .map { "- \($0.element)" }
                .joined(separator: "\n")

            let isEN = LanguageManager.shared.isEnglish
            let prompt: String
            if isEN {
                prompt = """
                You are an evaluation system. Below are observation records about \(npcName), and a hidden truth.
                Evaluate how close these observations are to revealing the truth. Score 0-10.
                Reply with only a single number.

                Truth: \(secret)
                Observations:
                \(memoryList)
                """
            } else {
                prompt = """
                你是一个评估系统。以下是关于\(npcName)的观察记录，以及一个隐藏的真相。
                请评估这些观察记录有多接近揭示真相。打分0-10。
                只回复一个数字。

                真相：\(secret)
                观察记录：
                \(memoryList)
                """
            }

            do {
                let session = LanguageModelSession(model: SystemLanguageModel.default)
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                // Parse the first integer found in the response
                if let score = Int(text), (0...10).contains(score) {
                    NHLogger.brain.info("[SecretScorer] Score for \(npcName): \(score)")
                    return score
                }
                // Try extracting a number from longer response
                let digits = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if let score = Int(digits.prefix(2)), (0...10).contains(score) {
                    NHLogger.brain.info("[SecretScorer] Parsed score for \(npcName): \(score)")
                    return score
                }
                NHLogger.brain.warning("[SecretScorer] Could not parse score from: \(text)")
            } catch {
                NHLogger.brain.error("[SecretScorer] Error: \(error)")
            }
        }
        #endif

        return 0
    }
}
