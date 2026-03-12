import Foundation
import Combine

@MainActor
final class DialogViewModel: ObservableObject {
    @Published private(set) var isVisible: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var locationName: String = ""
    @Published private(set) var leftName: String = ""
    @Published private(set) var rightName: String = ""
    @Published private(set) var leftColorHex: String = ""
    @Published private(set) var rightColorHex: String = ""
    @Published private(set) var leftProfileImage: String = ""
    @Published private(set) var rightProfileImage: String = ""
    @Published private(set) var lines: [DialogLine] = []
    @Published private(set) var index: Int = 0

    var onDismiss: (() -> Void)?
    private var activeToken: UUID?

    var currentLine: DialogLine? {
        guard index >= 0, index < lines.count else { return nil }
        return lines[index]
    }

    func present(
        conversation: DialogConversation,
        locationName: String,
        leftName: String,
        rightName: String,
        leftColorHex: String = "",
        rightColorHex: String = "",
        leftProfileImage: String = "",
        rightProfileImage: String = ""
    ) {
        self.locationName = locationName
        self.leftName = leftName
        self.rightName = rightName
        self.leftColorHex = leftColorHex
        self.rightColorHex = rightColorHex
        self.leftProfileImage = leftProfileImage
        self.rightProfileImage = rightProfileImage
        self.lines = conversation.lines
        self.index = 0
        self.isVisible = true
        self.isLoading = true
    }

    func replaceConversation(_ conversation: DialogConversation) {
        self.lines = conversation.lines
        self.index = 0
        self.isLoading = false
    }

    func setActiveToken(_ token: UUID) {
        self.activeToken = token
    }

    func isActive(token: UUID) -> Bool {
        activeToken == token
    }

    func next() {
        guard isVisible, !isLoading else { return }
        if index + 1 < lines.count {
            index += 1
        } else {
            dismiss()
        }
    }

    func dismiss() {
        guard isVisible else { return }
        isVisible = false
        isLoading = false
        activeToken = nil
        onDismiss?()
    }
}
