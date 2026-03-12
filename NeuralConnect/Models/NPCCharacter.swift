import Foundation

enum NPCGender: String {
    case male, female
    var pronounEN: String { self == .male ? "he" : "she" }
    var pronounZH: String { self == .male ? "他" : "她" }
    var possessiveEN: String { self == .male ? "his" : "her" }
    var possessiveZH: String { self == .male ? "他的" : "她的" }
}

struct NPCCharacter: Identifiable, Equatable, NPCDescriptor {
    let id: String
    let gender: NPCGender
    let name: String
    let role: String              // 公开身份
    let secret: String            // 核心秘密（一句话）
    let goal: String              // 行为驱动力（一句话）
    let archetype: String         // 性格原型
    let speechStyle: String       // 说话风格
    let preferredZones: [String]  // 常驻场景
    let agendas: [String]         // 主动行为目标 → 驱动自主移动和社交
    let background: String        // 生活背景 → 提供对话谈资
    let needTags: [String]        // 需求标签 → 驱动配对
    let offerTags: [String]       // 供给标签 → 驱动配对
    let avoidNPCIds: [String]     // 回避对象
    let baselinePressure: Int     // 初始压力值
    let dotColorHex: String
    let profileImage: String      // Asset catalog image name
    var spriteImage: String { profileImage + "2D" }

    // English equivalents
    let nameEN: String
    let roleEN: String
    let secretEN: String
    let goalEN: String
    let archetypeEN: String
    let speechStyleEN: String
    let agendasEN: [String]
    let backgroundEN: String

    var aiTemperature: Double {
        switch id {
        case "ai_android", "attendant":   return 0.5  // 精确、克制
        case "doctor", "gym_guy":        return 0.7  // 中等
        case "captain":                  return 0.85 // 紧张、不稳定
        case "stowaway":                return 0.9  // 警觉、跳跃
        default:                         return 0.7
        }
    }

    // Localized computed properties
    var localizedName: String { L(nameEN, name) }
    var localizedRole: String { L(roleEN, role) }
    var localizedSecret: String { L(secretEN, secret) }
    var localizedGoal: String { L(goalEN, goal) }
    var localizedArchetype: String { L(archetypeEN, archetype) }
    var localizedSpeechStyle: String { L(speechStyleEN, speechStyle) }
    var localizedAgendas: [String] { L(agendasEN.joined(separator: "\n"), agendas.joined(separator: "\n")).components(separatedBy: "\n") }
    var localizedBackground: String { L(backgroundEN, background) }

    // EverMemOS conventions
    var livedGroupId: String { "\(id)_lived" }
}
