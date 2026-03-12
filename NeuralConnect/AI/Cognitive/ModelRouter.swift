import Foundation

/// Decides which AI backend to use for a given task.
enum ModelRouter {

    enum AIBackend {
        case appleOnDevice
        case everMemOSChat
        case local // no AI needed
    }

    /// Route a conversation to the appropriate backend.
    static func routeConversation(
        leftId: String,
        rightId: String,
        isFirstEncounter: Bool
    ) -> AIBackend {
        // Android conversations always use cloud for deeper reasoning
        if leftId == "ai_android" || rightId == "ai_android" {
            return .everMemOSChat
        }

        // First encounter = more meaningful, use cloud
        if isFirstEncounter {
            return .everMemOSChat
        }

        // Default: fast on-device
        return .appleOnDevice
    }

    /// Hack reveals are always local (just reading stored data).
    static func routeHack() -> AIBackend {
        .local
    }

    /// Conversation summary generation.
    static func routeSummary() -> AIBackend {
        .appleOnDevice
    }

    /// Reflection generation.
    static func routeReflection() -> AIBackend {
        .appleOnDevice
    }
}
