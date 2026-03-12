import Foundation

/// Builds prompts for NPC dialogue, with EN/CN routing based on LanguageManager.
enum PromptBuilder {

    private static var isEnglish: Bool { LanguageManager.shared.isEnglish }

    /// Build system instructions for NPC conversation generation.
    static func systemInstructions() -> String {
        isEnglish ? systemInstructionsEN() : systemInstructionsCN()
    }

    private static func systemInstructionsCN() -> String {
        """
        你写简短、尖锐、有张力的对话（简体中文），场景是飞往火星的赛博朋克穿梭机，风格可类比泰坦尼克号：阶层混杂、暗流涌动。

        重要规则：
        - 绝不能说出秘密的全貌，但可以泄露一个让人后背发凉的细节——而且对方可能真的听懂了并追问
        - 对话要像真人——会开玩笑、会犯蠢、会情绪失控、会讽刺挖苦、会哈哈大笑
        - 每段对话至少一句让人嘴角上扬的台词——讽刺、自嘲、荒诞对比、犯蠢都可以
        - 每句话必须有新的信息，禁止重复相同的话题或措辞
        - 当一个角色说了可疑的话，另一个角色有权追问而不是假装没听到
        - 对话最后三句必须形成「刺痛-反应-余震」结构，禁止在高潮后立即结束
        - 只有医生和Android可以报精确数字，其他角色用感觉、情绪、口语说话
        - 引用过往对话时禁止说"你上次说"——应自然融入对方的词汇
        - 禁止固化表达：「你连……都」「破船」「没什么」「算了」「职业习惯」
        - 绝对禁止脏话、粗口（如"操""妈的""他妈的""靠""卧槽"等），愤怒用动作和语气表达，不能用脏字
        """
    }

    private static func systemInstructionsEN() -> String {
        """
        You write short, sharp, high-tension dialogue (in English) set on a cyberpunk shuttle bound for Mars — think Titanic: mixed social classes, hidden agendas, undercurrents everywhere.

        Key rules:
        - Never reveal a secret in full, but leak one spine-chilling detail — and the other person may actually catch it and press further
        - Dialogue must feel real — people joke, make mistakes, lose their temper, use sarcasm, laugh out loud
        - Every exchange needs at least one line that makes the reader smirk — sarcasm, self-deprecation, absurd contrasts, blunders
        - Every line must carry new information; no repeating the same topic or phrasing
        - When one character says something suspicious, the other has the right to follow up instead of pretending they didn't hear it
        - The last three lines must form a "sting → reaction → aftershock" structure; never end right after the climax
        - Only the Doctor and Android may cite precise numbers; everyone else speaks in feelings, emotions, and colloquialisms
        - When referencing past conversations, never say "you said last time" — weave the other person's words in naturally
        - Banned clichés: "you can't even…", "this damn ship", "it's nothing", "forget it", "occupational habit"
        - Absolutely no profanity or swearing. Characters can be angry but must express it through actions and tone, never with swear words
        """
    }

    // MARK: - Relationship & Agenda Helpers

    static func relationshipDescription(
        fromName: String, toName: String,
        trust: Int, suspicion: Int, debt: Int, pressure: Int
    ) -> String {
        isEnglish
            ? relationshipDescriptionEN(fromName: fromName, toName: toName, trust: trust, suspicion: suspicion, debt: debt)
            : relationshipDescriptionCN(fromName: fromName, toName: toName, trust: trust, suspicion: suspicion, debt: debt)
    }

    private static func relationshipDescriptionCN(
        fromName: String, toName: String,
        trust: Int, suspicion: Int, debt: Int
    ) -> String {
        var parts: [String] = []
        let trustDesc: String
        switch trust {
        case 0: trustDesc = "陌生人"
        case 1: trustDesc = "有过接触"
        case 2: trustDesc = "有些信任"
        case 3: trustDesc = "比较信赖"
        default: trustDesc = "非常信赖"
        }
        parts.append("对\(toName)：\(trustDesc)")
        if suspicion >= 1 {
            let suspDesc: String
            switch suspicion {
            case 1: suspDesc = "略有疑虑"
            case 2: suspDesc = "有些警觉"
            case 3: suspDesc = "相当怀疑"
            default: suspDesc = "强烈怀疑"
            }
            parts.append("同时\(suspDesc)")
        }
        if debt > 0 {
            parts.append("欠\(toName)人情")
        }
        return parts.joined(separator: "，")
    }

    private static func relationshipDescriptionEN(
        fromName: String, toName: String,
        trust: Int, suspicion: Int, debt: Int
    ) -> String {
        var parts: [String] = []
        let trustDesc: String
        switch trust {
        case 0: trustDesc = "strangers"
        case 1: trustDesc = "have met before"
        case 2: trustDesc = "somewhat trusting"
        case 3: trustDesc = "fairly trusting"
        default: trustDesc = "deeply trusting"
        }
        parts.append("Toward \(toName): \(trustDesc)")
        if suspicion >= 1 {
            let suspDesc: String
            switch suspicion {
            case 1: suspDesc = "slightly wary"
            case 2: suspDesc = "on guard"
            case 3: suspDesc = "quite suspicious"
            default: suspDesc = "deeply suspicious"
            }
            parts.append("also \(suspDesc)")
        }
        if debt > 0 {
            parts.append("owes \(toName) a favor")
        }
        return parts.joined(separator: ", ")
    }

    /// Filter NPC agendas to those relevant to a specific other NPC.
    static func relevantAgendas(for npc: NPCCharacter, about other: NPCCharacter) -> [String] {
        let keywords = [other.localizedName, other.localizedRole]
        let agendas = npc.localizedAgendas
        let matched = agendas.filter { agenda in
            keywords.contains { agenda.contains($0) }
        }
        if !matched.isEmpty {
            return Array(matched.prefix(2))
        }
        return Array(agendas.prefix(1))
    }

    /// Build NPC inner motivation block for prompt injection.
    private static func motivationBlock(
        npc: NPCCharacter, other: NPCCharacter,
        trust: Int, suspicion: Int, debt: Int, pressure: Int
    ) -> String {
        let agendas = relevantAgendas(for: npc, about: other)
        let relDesc = relationshipDescription(
            fromName: npc.localizedName, toName: other.localizedName,
            trust: trust, suspicion: suspicion, debt: debt, pressure: pressure
        )

        if isEnglish {
            var block = "\n\n[\(npc.localizedName)'s Inner Motivation] (AI-only — character won't say this directly)"
            block += "\nGoal: \(npc.localizedGoal)"
            block += "\nCurrent focus: \(agendas.joined(separator: "; "))"
            block += "\n\(relDesc)"
            if pressure >= 1 {
                let pressureDesc: String
                switch pressure {
                case 1: pressureDesc = "somewhat anxious"
                case 2: pressureDesc = "under significant pressure"
                default: pressureDesc = "under extreme pressure"
                }
                block += "\nInner state: \(pressureDesc)"
            }
            return block
        } else {
            var block = "\n\n【\(npc.localizedName)的内在动机】（仅AI可见，角色不会直说）"
            block += "\n目标：\(npc.localizedGoal)"
            block += "\n当前关注：\(agendas.joined(separator: "；"))"
            block += "\n\(relDesc)"
            if pressure >= 1 {
                let pressureDesc: String
                switch pressure {
                case 1: pressureDesc = "有些焦虑"
                case 2: pressureDesc = "压力较大"
                default: pressureDesc = "压力极大"
                }
                block += "\n内心状态：\(pressureDesc)"
            }
            return block
        }
    }

    // MARK: - Conversation Prompt

    static func conversationPrompt(
        left: NPCCharacter,
        right: NPCCharacter,
        locationName: String,
        leftMemories: [String] = [],
        rightMemories: [String] = [],
        leftForesights: [String] = [],
        rightForesights: [String] = [],
        leftRecentPhrases: [String] = [],
        rightRecentPhrases: [String] = [],
        conversationTags: [String] = [],
        intent: ConversationIntent? = nil,
        trustLR: Int = 0, trustRL: Int = 0,
        suspicionLR: Int = 0, suspicionRL: Int = 0,
        debtLR: Int = 0, debtRL: Int = 0,
        pressureL: Int = 0, pressureR: Int = 0
    ) -> String {
        let ln = left.localizedName
        let rn = right.localizedName

        var prompt: String
        if isEnglish {
            prompt = """
            Location: \(locationName)

            \(ln) (\(left.localizedRole), \(left.gender.pronounEN)) \(left.localizedArchetype), \(left.localizedSpeechStyle)
            Background: \(left.localizedBackground)

            \(rn) (\(right.localizedRole), \(right.gender.pronounEN)) \(right.localizedArchetype), \(right.localizedSpeechStyle)
            Background: \(right.localizedBackground)
            """
        } else {
            prompt = """
            场所：\(locationName)

            \(ln)（\(left.localizedRole)，\(left.gender.pronounZH)）\(left.localizedArchetype)，\(left.localizedSpeechStyle)
            背景：\(left.localizedBackground)

            \(rn)（\(right.localizedRole)，\(right.gender.pronounZH)）\(right.localizedArchetype)，\(right.localizedSpeechStyle)
            背景：\(right.localizedBackground)
            """
        }

        // Inner motivations
        prompt += motivationBlock(
            npc: left, other: right,
            trust: trustLR, suspicion: suspicionLR, debt: debtLR, pressure: pressureL
        )
        prompt += motivationBlock(
            npc: right, other: left,
            trust: trustRL, suspicion: suspicionRL, debt: debtRL, pressure: pressureR
        )

        // Anti-repetition
        if !leftRecentPhrases.isEmpty || !rightRecentPhrases.isEmpty {
            if isEnglish {
                var dedupLines: [String] = ["[No Repetition] The following are lines recently spoken by these characters. This conversation MUST use completely different wording:"]
                if !leftRecentPhrases.isEmpty {
                    dedupLines.append("\(ln): \(leftRecentPhrases.map { "\"\($0)\"" }.joined(separator: " "))")
                }
                if !rightRecentPhrases.isEmpty {
                    dedupLines.append("\(rn): \(rightRecentPhrases.map { "\"\($0)\"" }.joined(separator: " "))")
                }
                prompt += "\n\n" + dedupLines.joined(separator: "\n")
            } else {
                var dedupLines: [String] = ["【禁止重复】以下是角色最近说过的话，本次对话中禁止使用相同或相似的措辞，必须换全新的表达方式："]
                if !leftRecentPhrases.isEmpty {
                    dedupLines.append("\(ln)：\(leftRecentPhrases.map { "「\($0)」" }.joined(separator: " "))")
                }
                if !rightRecentPhrases.isEmpty {
                    dedupLines.append("\(rn)：\(rightRecentPhrases.map { "「\($0)」" }.joined(separator: " "))")
                }
                prompt += "\n\n" + dedupLines.joined(separator: "\n")
            }
        }

        // Previously discussed topics (from ConversationMeta tags)
        if !conversationTags.isEmpty {
            if isEnglish {
                prompt += "\n\n[Previously Discussed Topics] These topics have already come up between them: \(conversationTags.joined(separator: ", ")). This conversation should NOT rehash these — find fresh angles or new topics."
            } else {
                prompt += "\n\n【已讨论话题】以下话题双方之前已经聊过：\(conversationTags.joined(separator: "、"))。本次对话不要重复这些话题，必须找到新的角度或全新话题。"
            }
        }

        // Memories section
        if !leftMemories.isEmpty {
            prompt += isEnglish
                ? "\n\n\(ln)'s recent impressions of \(rn):"
                : "\n\n\(ln)对\(rn)的最近印象："
            for mem in leftMemories.prefix(5) {
                prompt += "\n  · \(truncateMemory(mem))"
            }
        }
        if !rightMemories.isEmpty {
            prompt += isEnglish
                ? "\n\n\(rn)'s recent impressions of \(ln):"
                : "\n\n\(rn)对\(ln)的最近印象："
            for mem in rightMemories.prefix(5) {
                prompt += "\n  · \(truncateMemory(mem))"
            }
        }

        // Foresights (intentions/predictions for next interaction)
        if !leftForesights.isEmpty {
            prompt += isEnglish
                ? "\n\n\(ln)'s intentions regarding \(rn) (won't say directly, but drives behavior):"
                : "\n\n\(ln)对\(rn)接下来的打算（不会直说，但会驱动行为）："
            for f in leftForesights.prefix(3) {
                prompt += "\n  · \(truncateMemory(f))"
            }
        }
        if !rightForesights.isEmpty {
            prompt += isEnglish
                ? "\n\n\(rn)'s intentions regarding \(ln) (won't say directly, but drives behavior):"
                : "\n\n\(rn)对\(ln)接下来的打算（不会直说，但会驱动行为）："
            for f in rightForesights.prefix(3) {
                prompt += "\n  · \(truncateMemory(f))"
            }
        }

        // Approach evolution
        if !leftMemories.isEmpty || !rightMemories.isEmpty {
            if isEnglish {
                prompt += "\n\n[Important: Conversation Progression] The above are impressions from previous interactions. This conversation MUST build on them — no repeating the same opening angle or topic. If the last conversation was casual probing, be more direct this time. If the other person dodged a question last time, approach that sensitive point from a completely different angle."
                prompt += "\n[Dialogue References] Characters should naturally reference past interactions — e.g., 'that thing you mentioned...', 'I've been thinking about what you said...' This creates continuity instead of starting from scratch each time."
            } else {
                prompt += "\n\n【重要：对话递进要求】以上是双方之前互动的印象。本次对话必须在此基础上推进，禁止重复上次的切入角度和话题。如果上次是闲聊试探，这次要更直接；如果上次对方回避了某个问题，这次要用完全不同的方式再次触及那个敏感点。"
                prompt += "\n【对话引用】角色应该自然地引用之前的互动——比如'上次你说的那个……'、'你之前提到过……'、'我一直在想你上次说的话'。这让对话有连续性，而不是每次都从零开始。"
            }

            let allMemories = leftMemories + rightMemories
            if allMemories.count >= 3 {
                let bannedTopics = extractHighFrequencyTopics(from: allMemories)
                if !bannedTopics.isEmpty {
                    if isEnglish {
                        prompt += "\n\n[Topic Refresh] These two have talked many times. This conversation must NOT revisit these already-discussed topics: \(bannedTopics.joined(separator: ", ")). Find a completely new angle."
                    } else {
                        prompt += "\n\n【话题刷新】双方已交谈多次。本次对话禁止再提及以下已经聊过的话题：\(bannedTopics.joined(separator: "、"))。必须从一个全新的角度切入。"
                    }
                }
            }
        }

        // Intent-driven section
        if let intent = intent {
            let initiatorName = intent.initiatorId == left.id ? ln : rn
            let responderName = intent.responderId == left.id ? ln : rn

            if isEnglish {
                prompt += "\n\nWhy they meet now: \(intent.whyNow)"
                prompt += "\nWho speaks first: \(initiatorName)"

                switch intent.mode {
                case .askHelp:
                    prompt += "\nInteraction mode: \(initiatorName) seeks help from \(responderName)"
                    prompt += "\n\(initiatorName)'s needs: \(intent.initiatorNeedTags.joined(separator: ", "))"
                    prompt += "\n\(responderName) can offer: \(intent.responderOfferTags.joined(separator: ", "))"
                case .exchange:
                    prompt += "\nInteraction mode: Both have needs — a mutual exchange"
                case .repay:
                    prompt += "\nInteraction mode: \(initiatorName) wants to repay \(responderName) for past help"
                case .probe:
                    prompt += "\nInteraction mode: One strongly suspects the other and is probing during conversation"
                    prompt += "\nApproach: indirect hints, bait topics, watching reactions — never direct confrontation"
                case .casual:
                    prompt += "\nInteraction mode: Seemingly casual chat, but both have hidden agendas"
                    prompt += "\nRequirement: There must be one small turn — a slip of the tongue, a nerve struck, or an awkward silence"
                case .avoid:
                    prompt += "\nInteraction mode: One doesn't want to talk but is forced into the encounter"
                    prompt += "\nApproach: brush-offs, excuses, trying to leave quickly"
                }

                if !intent.allowedTopics.isEmpty {
                    prompt += "\nAllowed topics: \(intent.allowedTopics.joined(separator: ", "))"
                }
                prompt += "\nForbidden topics: \(intent.forbiddenTopics.joined(separator: ", "))"

                if intent.secretPressureActiveLeft {
                    let style = secretPressureStyle(for: left.id, partnerId: right.id, trust: trustLR)
                    prompt += "\n\n[\(ln)'s Private High-Pressure Constraint] This person carries a secret: \(left.localizedSecret). The secret puts them under extreme pressure, but they must never say it outright. \(style)"
                    prompt += "\nImportant: If \(ln) lets something slip, \(rn) has the right to press, question, or remember — don't let every leak be easily deflected."
                }
                if intent.secretPressureActiveRight {
                    let style = secretPressureStyle(for: right.id, partnerId: left.id, trust: trustRL)
                    prompt += "\n\n[\(rn)'s Private High-Pressure Constraint] This person carries a secret: \(right.localizedSecret). The secret puts them under extreme pressure, but they must never say it outright. \(style)"
                    prompt += "\nImportant: If \(rn) lets something slip, \(ln) has the right to press, question, or remember — don't let every leak be easily deflected."
                }
            } else {
                prompt += "\n\n本次相遇原因：\(intent.whyNow)"
                prompt += "\n先开口的人：\(initiatorName)"

                switch intent.mode {
                case .askHelp:
                    prompt += "\n互动模式：\(initiatorName)向\(responderName)寻求帮助"
                    prompt += "\n\(initiatorName)的需求：\(intent.initiatorNeedTags.joined(separator: "、"))"
                    prompt += "\n\(responderName)能提供：\(intent.responderOfferTags.joined(separator: "、"))"
                case .exchange:
                    prompt += "\n互动模式：双方互有需求，进行交换"
                case .repay:
                    prompt += "\n互动模式：\(initiatorName)想报答\(responderName)之前的帮助"
                case .probe:
                    prompt += "\n互动模式：一方对另一方有强烈怀疑，在对话中试探"
                    prompt += "\n表现为旁敲侧击、抛出诱饵话题、观察反应，绝不直接质问"
                case .casual:
                    prompt += "\n互动模式：看似日常闲聊，但双方各有心思"
                    prompt += "\n要求：对话中必须有一个小转折——某人说漏嘴、某句话戳中痛点、或某个尴尬的沉默"
                case .avoid:
                    prompt += "\n互动模式：一方不想和对方交流，但被迫碰面"
                    prompt += "\n表现为敷衍、找借口、尽快结束"
                }

                if !intent.allowedTopics.isEmpty {
                    prompt += "\n允许话题：\(intent.allowedTopics.joined(separator: "、"))"
                }
                prompt += "\n禁止话题：\(intent.forbiddenTopics.joined(separator: "、"))"

                if intent.secretPressureActiveLeft {
                    let style = secretPressureStyle(for: left.id, partnerId: right.id, trust: trustLR)
                    prompt += "\n\n【\(ln)的私有高压约束】这个人内心藏着一个秘密：\(left.localizedSecret)。这个秘密让ta压力极大，但绝不能直接说出来。\(style)"
                    prompt += "\n重要：如果\(ln)说漏了什么，\(rn)有权追问、质疑或记住——不要让每次泄露都被轻易岔开。"
                }
                if intent.secretPressureActiveRight {
                    let style = secretPressureStyle(for: right.id, partnerId: left.id, trust: trustRL)
                    prompt += "\n\n【\(rn)的私有高压约束】这个人内心藏着一个秘密：\(right.localizedSecret)。这个秘密让ta压力极大，但绝不能直接说出来。\(style)"
                    prompt += "\n重要：如果\(rn)说漏了什么，\(ln)有权追问、质疑或记住——不要让每次泄露都被轻易岔开。"
                }
            }
        } else {
            // Fallback: no intent available
            let isFirstMeeting = leftMemories.isEmpty && rightMemories.isEmpty
            if isFirstMeeting {
                let leftAgenda = relevantAgendas(for: left, about: right).first ?? left.localizedAgendas.first ?? ""
                let rightAgenda = relevantAgendas(for: right, about: left).first ?? right.localizedAgendas.first ?? ""
                if isEnglish {
                    prompt += "\n\nThis is their first meeting."
                    prompt += "\n\(ln)'s current focus: \(leftAgenda)"
                    prompt += "\n\(rn)'s current focus: \(rightAgenda)"
                    prompt += "\nDevelop the conversation based on their backgrounds and current focus, naturally probing each other."
                } else {
                    prompt += "\n\n这是两人第一次见面。"
                    prompt += "\n\(ln)当前最关注：\(leftAgenda)"
                    prompt += "\n\(rn)当前最关注：\(rightAgenda)"
                    prompt += "\n基于各自的背景和当前关注展开对话，自然地互相试探。"
                }
            } else {
                if isEnglish {
                    prompt += "\n\nThey've met several times before. Continue developing the relationship based on recent impressions, but discuss new topics — no repeating what's already been covered."
                } else {
                    prompt += "\n\n两人已经见过多次。基于最近的印象继续发展关系，但必须聊新话题——禁止重复之前已经聊过的内容。"
                }
            }
        }

        return prompt
    }

    /// Build a summary prompt for after-conversation memory generation.
    static func summaryPrompt(
        npcName: String,
        partnerName: String,
        dialogue: [String]
    ) -> String {
        let lines = dialogue.joined(separator: "\n")
        if isEnglish {
            return """
            You are \(npcName). Here is your conversation with \(partnerName):
            \(lines)

            In one sentence (first person "I"), summarize what you noticed or felt during this conversation. Note: you are \(npcName) — do not refer to yourself in the third person. Output only the summary.
            """
        } else {
            return """
            你是\(npcName)。以下是你和\(partnerName)刚才的对话：
            \(lines)

            用一句简体中文（第一人称"我"）总结这次对话中你注意到的事情或你的感受。注意：你是\(npcName)，不要用第三人称称呼自己。只输出总结，不要使用英文。
            """
        }
    }

    // MARK: - Observation & Reflection Prompts

    static func observationPrompt(
        observerName: String,
        observerRole: String,
        targetName: String,
        targetRole: String,
        zone: String,
        observerGoal: String = ""
    ) -> String {
        if isEnglish {
            var p = "You are \(observerName) (\(observerRole)). You see \(targetName) (\(targetRole)) in the \(zone)."
            if !observerGoal.isEmpty {
                p += "\nWhat you care about most: \(observerGoal)"
                p += "\nDescribe your observation in one sentence, paying special attention to details related to what you care about. First person, no more than 30 words. Output only the observation."
            } else {
                p += "\nDescribe your observation in one sentence (first person), no more than 30 words. Output only the observation."
            }
            return p
        } else {
            var p = "你是\(observerName)（\(observerRole)），你在\(zone)看到\(targetName)（\(targetRole)）。"
            if !observerGoal.isEmpty {
                p += "\n你内心最在意的事：\(observerGoal)"
                p += "\n用一句话描述你的观察，特别注意和你在意的事相关的细节。第一人称，不超过30个汉字。只输出观察。"
            } else {
                p += "\n用一句话描述你的观察（第一人称），不超过30个汉字。只输出观察。"
            }
            return p
        }
    }

    static func reflectionPrompt(
        npcName: String,
        npcRole: String,
        memories: [String]
    ) -> String {
        let memoryList = memories.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        if isEnglish {
            return """
            You are \(npcName) (\(npcRole)). Here are your recent experiences:
            \(memoryList)

            Synthesize these experiences into one cross-person insight or intuition (first person), no more than 40 words. Focus on: Are different people connected? Who is hiding something? Are there undercurrents on the ship you hadn't noticed? Output only the reflection.
            """
        } else {
            return """
            你是\(npcName)（\(npcRole)）。以下是你最近的经历：
            \(memoryList)

            综合这些经历，写出一个跨越多个人的洞察或直觉（第一人称），不超过40个汉字。重点关注：不同人之间是否有关联？谁在隐瞒什么？船上是否有你之前没注意到的暗流？只输出反思。
            """
        }
    }

    // MARK: - Secret Pressure Styles

    static func secretPressureStyle(for npcId: String, partnerId: String, trust: Int = 0) -> String {
        let styles: [String]
        if isEnglish {
            styles = [
                "Expression this time: Suddenly shifts to a seemingly unrelated topic that's actually loaded with hidden meaning, as if asking for help in a roundabout way. The other person may press for the real meaning.",
                "Expression this time: Overreacts to an innocuous word, revealing an inner sensitive spot. Then tries to cover it up but only makes it worse — and this time the other person notices.",
                "Expression this time: Accidentally reveals a detail they shouldn't know, immediately tries to cover with a lie that has an obvious flaw. The other person may point out the contradiction on the spot.",
                "Expression this time: Says something ambiguous, meant as a probe, but the other person interprets it differently, sending the conversation in an unexpected direction.",
                "Expression this time: Shows abnormal concern or hostility toward the other person — clearly disproportionate to their current relationship. The other person directly asks 'Why are you suddenly acting like this?'",
                "Expression this time: After a drink or when too tired, defenses drop and they say something genuinely true — not a vague hint but a specific, dangerous truth. Only realizes the mistake after saying it.",
            ]
        } else {
            styles = [
                "本次表现方式：突然转移到一个看似无关但暗含深意的话题，像是在拐弯抹角地求助。对方可能会追问这个话题的真实含义。",
                "本次表现方式：对一个无害的词过度解释或反应过激，暴露出内心的敏感点。然后试图掩饰但越描越黑——而对方这次注意到了。",
                "本次表现方式：不小心说出一个不该知道的细节，立刻试图用谎言覆盖，但谎言有明显破绽。对方可能当场指出矛盾。",
                "本次表现方式：说了一句模棱两可的话，本意是试探，但对方理解成了别的意思，导致对话走向意想不到的方向。",
                "本次表现方式：对对方表现出反常的关心或敌意——明显超出了当前关系应有的程度。对方直接问'你为什么突然这样？'",
                "本次表现方式：喝了酒或太累时防线松动，说出一句真心话——不是含糊暗示，而是一句真正的、具体的、危险的真话。说完才意识到不对。",
            ]
        }
        let charSum = (npcId + partnerId).unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let idx = (charSum + trust) % styles.count
        return styles[idx]
    }

    // MARK: - Topic Extraction

    static func extractHighFrequencyTopics(from memories: [String]) -> [String] {
        let allText = memories.joined(separator: " ")
        // Chinese + English punctuation delimiters
        let delimiters = "\u{FF0C}\u{3002}\u{FF01}\u{FF1F}\u{3001}\u{FF1B}\u{FF1A}\u{201C}\u{201D}\u{2018}\u{2019}\u{FF08}\u{FF09}\u{2026}\u{2014},.!?;:\"'() \n"
        let segments = allText.components(separatedBy: CharacterSet(charactersIn: delimiters))
            .filter { $0.count >= 2 && $0.count <= 6 }

        var freq: [String: Int] = [:]
        for seg in segments {
            freq[seg, default: 0] += 1
        }

        let result = freq.filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }

        return result
    }

    // MARK: - Memory Truncation

    static func truncateMemory(_ text: String) -> String {
        var s = text
        let patterns = [
            #"^在?\d{4}年\d{1,2}月\d{1,2}日[^，,]*[，,]\s*"#,
            #"^On \w+ \d{1,2}, \d{4}[^,]*,\s*"#,
            #"^\d{4}年\d{1,2}月\d{1,2}日[^，,]*[，,]\s*"#,
        ]
        for pattern in patterns {
            if let range = s.range(of: pattern, options: .regularExpression) {
                s = String(s[range.upperBound...])
            }
        }
        if s.count > 80 {
            let idx = s.index(s.startIndex, offsetBy: 77)
            s = s[s.startIndex..<idx] + "…"
        }
        return s
    }

    // MARK: - Safety Sanitization

    /// Sanitize text to avoid triggering Apple on-device model safety guardrails.
    /// Only applies in Chinese mode (Apple FoundationModels safety is Chinese-specific).
    static func sanitize(_ text: String) -> String {
        guard !isEnglish else { return text }

        var s = text
        s = s.replacingOccurrences(of: "偷渡少年", with: "少年")
        s = s.replacingOccurrences(of: "偷渡者", with: "杂工")
        s = s.replacingOccurrences(of: "偷渡", with: "悄悄登船")
        s = s.replacingOccurrences(of: "通缉犯", with: "可疑人物")
        s = s.replacingOccurrences(of: "间谍", with: "神秘人")
        s = s.replacingOccurrences(of: "假名", with: "化名")
        s = s.replacingOccurrences(of: "假证", with: "证件")
        s = s.replacingOccurrences(of: "Phantom", with: "少年")
        s = s.replacingOccurrences(of: "破解过军方防火墙", with: "研究过复杂系统")
        s = s.replacingOccurrences(of: "军方防火墙", with: "复杂系统")
        s = s.replacingOccurrences(of: "防火墙", with: "系统")
        s = s.replacingOccurrences(of: "黑客", with: "技术高手")
        s = s.replacingOccurrences(of: "破解", with: "研究")
        s = s.replacingOccurrences(of: "漏洞", with: "特点")
        s = s.replacingOccurrences(of: "核心指令代码", with: "核心参数")
        s = s.replacingOccurrences(of: "指令代码", with: "参数")
        s = s.replacingOccurrences(of: "门禁记录", with: "出入记录")
        s = s.replacingOccurrences(of: "门禁", with: "出入")
        s = s.replacingOccurrences(of: "权限", with: "通行码")
        s = s.replacingOccurrences(of: "被组织追杀", with: "被人追踪")
        s = s.replacingOccurrences(of: "追杀", with: "追踪")
        s = s.replacingOccurrences(of: "人体实验", with: "医学研究")
        s = s.replacingOccurrences(of: "临床死亡", with: "重伤")
        s = s.replacingOccurrences(of: "再次死亡", with: "出问题")
        s = s.replacingOccurrences(of: "基因采样", with: "体检")
        s = s.replacingOccurrences(of: "淤青", with: "旧伤")
        s = s.replacingOccurrences(of: "深层组织", with: "状况")
        s = s.replacingOccurrences(of: "跟踪我", with: "注意我")
        s = s.replacingOccurrences(of: "跟踪", with: "留意")
        s = s.replacingOccurrences(of: "监控", with: "观察")
        s = s.replacingOccurrences(of: "窃听", with: "旁听")
        s = s.replacingOccurrences(of: "清洗其记忆", with: "重置档案")
        s = s.replacingOccurrences(of: "引发恐慌", with: "引起关注")
        return s
    }
}
