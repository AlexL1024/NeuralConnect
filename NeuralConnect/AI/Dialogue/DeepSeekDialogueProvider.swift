import Foundation
import os.log

struct DeepSeekDialogueProvider: DialogueProvider {

    init() {
        NHLogger.dialogue.info("[DeepSeek] Provider initialized, model=deepseek-chat")
    }

    func generateConversation(context: ConversationContext) async -> DialogConversation {
        let left = context.group.left.displayName
        let right = context.group.right.displayName

        let isEN = LanguageManager.shared.isEnglish

        let systemPromptCN = """
        你是对话写手。场景：飞往火星的赛博朋克穿梭机，六个月航程，六个各怀秘密的人被关在一起。

        核心原则：
        - 这些人在一起生活了很久，他们会开玩笑、吐槽、自嘲、冷幽默——不是每句话都在试探
        - 不是所有人都聪明。有人会漏掉暗示，有人会误读信号，有人反应迟钝
        - 真正的冲突必须发生：有人会摔东西、有人会说出收不回去的话、有人会当面撕破脸
        - 幽默是必需品。每段对话至少要有一句让人嘴角上扬的台词。参考各角色的幽默风格：少年嘴贱吐槽（"医生你那手再抖下去可以当人肉搅拌机了"）、健身男冷面黑色幽默（"我上一个室友也喜欢半夜散步，后来在他枕头底下发现了三把刀和一本诗集"）、舰长粗人冷幽默（"你们文化人管这叫存在危机，我们货运的管这叫——货没了"）、Android一本正经说荒谬的话（"根据数据库，人类说'没事'时实际没事的概率是百分之四"）

        结构要求：
        - 对话最后三句必须形成「刺痛-反应-余震」：倒数第三句触及对方秘密，倒数第二句被触及方必须有非理性反应（攻击/撒谎/身体失控），最后一句发起方意识到捅了马蜂窝但来不及收回
        - 禁止以下结尾方式：沉默、说"没什么"、说"算了"、转移到无关话题
        - 对话长度要有变化：有时4-5句刀刀见血，有时8-10句慢慢积累到爆发点
        - 同一个比喻在整段对话中最多出现1次

        写作禁忌：
        - 禁止直接说出秘密的全貌，但允许泄露一个致命细节——而且对方可能真的听懂了
        - 禁止"揭示→收回"的万能套路——对方有权追问、记住、事后找别人求证
        - 禁止以下固化表达：「你连……都」「0.3」「破船」「破X」「上次你说」「没什么」「算了」「职业习惯」「抱歉」
        - 引用过往对话时禁止用"你上次说"——应该自然融入对方的词汇或被情景触发
        - 禁止用"（停顿）"——用具体动作替代，且动作必须涉及环境（墙壁、桌子、窗户、食物），不能只是手部动作
        - 只有医生和Android可以报精确数字，其他角色用感觉和口语说话
        - 绝对禁止脏话、粗口、骂人的话（如"操""妈的""他妈的""靠""卧槽"等），角色可以愤怒但必须用动作和语气表达，不能用脏字

        输出格式（严格遵守）：
        - 4到10行对话，绝不能超过10行
        - 每行格式：角色名: 开头（例如「\(left): 台词」或「\(right): 台词」）
        - 每句不超过50个汉字
        - 只输出对话，不要任何其他内容
        """

        let systemPromptEN = """
        You are a dialogue writer. Setting: a cyberpunk shuttle bound for Mars, six-month voyage, six people each hiding secrets trapped together.

        Core principles:
        - These people have lived together for a while — they joke, complain, self-deprecate, use dry humor. Not every line is probing
        - Not everyone is smart. Some miss hints, some misread signals, some react slowly
        - Real conflict must happen: someone slams something, someone says something they can't take back, someone confronts another face-to-face
        - Humor is mandatory. At least one line per exchange that makes the reader smirk. Reference each character's humor style: The Stowaway's sharp tongue ("Doc, if your hand shakes any harder you could moonlight as a blender"), Gym Guy's deadpan dark humor ("My last roommate also liked midnight walks. Later I found three knives and a poetry book under his pillow"), Captain's rough humor ("You cultured folks call it an existential crisis. In freight we call it — the cargo's gone"), Android's absurd deadpan ("According to the database, when humans say 'I'm fine,' the probability of actually being fine is four percent")

        Structure:
        - The last three lines must form "sting → reaction → aftershock": third-to-last touches on the other's secret, second-to-last the stung party must react irrationally (attack/lie/physical glitch), final line the initiator realizes they've kicked a hornet's nest but can't take it back
        - Banned endings: silence, "it's nothing," "forget it," pivoting to an unrelated topic
        - Vary length: sometimes 4-5 lines cutting deep, sometimes 8-10 lines building to an explosion
        - Any metaphor may appear at most once in a single exchange

        Writing rules:
        - Never reveal a secret fully, but allow one lethal detail to slip — and the other person may actually understand
        - Ban the "reveal → retract" formula — the other party can follow up, remember, or verify with someone else later
        - Banned clichés: "you can't even…", "0.3", "this damn ship", "you said last time", "it's nothing", "forget it", "occupational habit", "sorry"
        - When referencing past conversations, never use "you said last time" — weave words naturally or trigger by context
        - Ban "(pause)" — replace with a concrete action involving the environment (wall, table, window, food), not just hand gestures
        - Only the Doctor and Android may cite precise numbers; everyone else speaks in feelings and colloquialisms
        - Absolutely no profanity, swearing, or vulgar language. Characters can be angry but must express it through actions and tone, never with swear words

        Output format (strictly follow):
        - 4 to 10 lines of dialogue, never more than 10
        - Each line format: Character name: followed by the line (e.g., "\(left): dialogue" or "\(right): dialogue")
        - Each line no more than 80 characters
        - Output only the dialogue, nothing else
        """

        let systemPrompt = isEN ? systemPromptEN : systemPromptCN

        let rc = context.relationshipContext
        let tLR = rc?.trustLR ?? 0; let tRL = rc?.trustRL ?? 0
        let sLR = rc?.suspicionLR ?? 0; let sRL = rc?.suspicionRL ?? 0
        let dLR = rc?.debtLR ?? 0; let dRL = rc?.debtRL ?? 0
        let pL = rc?.pressureL ?? 0; let pR = rc?.pressureR ?? 0
        let userPrompt = PromptBuilder.conversationPrompt(
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

        NHLogger.dialogue.debug("[DeepSeek] Generating for \(left) ↔ \(right) in \(context.group.locationId)")

        do {
            let responseText = try await DeepSeekAPI.generate(system: systemPrompt, user: userPrompt)
            var lines = parseLines(responseText, leftName: left, rightName: right)
            if lines.count > 10 {
                NHLogger.dialogue.debug("[DeepSeek] Truncating \(lines.count) lines to 10, keeping ending")
                lines = Array(lines.suffix(10))
            }
            if !lines.isEmpty {
                NHLogger.dialogue.info("[DeepSeek] ✅ Generated \(lines.count) lines for \(left) ↔ \(right)")
                for (i, line) in lines.enumerated() {
                    let side = line.speaker == .left ? left : right
                    NHLogger.dialogue.debug("[DeepSeek]   [\(i+1)] \(side): \(line.text)")
                }
                return DialogConversation(lines: lines)
            }
            NHLogger.dialogue.warning("[DeepSeek] Parsed 0 lines from response. Raw: \(responseText.prefix(200))")
        } catch {
            NHLogger.dialogue.error("[DeepSeek] ❌ Generation error: \(error)")
        }

        return .placeholder(
            groupId: context.group.id,
            leftName: left,
            rightName: right,
            note: "DeepSeek error"
        )
    }

    // MARK: - Parse Response

    private func parseLines(_ text: String, leftName: String, rightName: String) -> [DialogLine] {
        // Build prefix variants: "名字:" and "名字：" (half/full-width colon)
        let leftPrefixes = [leftName + ":", leftName + "："]
        let rightPrefixes = [rightName + ":", rightName + "："]
        // Also keep L:/R: as fallback
        let leftAll = leftPrefixes + ["L:", "L："]
        let rightAll = rightPrefixes + ["R:", "R："]

        var lines: [DialogLine] = []
        for raw in text.components(separatedBy: .newlines) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let speaker: DialogLine.Speaker
            let content: String

            if let prefix = leftAll.first(where: { trimmed.hasPrefix($0) }) {
                speaker = .left
                content = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            } else if let prefix = rightAll.first(where: { trimmed.hasPrefix($0) }) {
                speaker = .right
                content = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            } else {
                NHLogger.dialogue.debug("[DeepSeek] Skipped unparseable line: \(trimmed.prefix(60))")
                continue
            }

            guard !content.isEmpty else { continue }
            lines.append(DialogLine(speaker: speaker, text: content))
        }
        return lines
    }
}
