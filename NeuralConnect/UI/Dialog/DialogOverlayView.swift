import SwiftUI

struct DialogOverlayView: View {
    @ObservedObject var viewModel: DialogViewModel

    var body: some View {
        Group {
            if viewModel.isVisible {
                GeometryReader { geometry in
                    ZStack {
                        // Light dim — let game scene show through
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                            .onTapGesture { viewModel.next() }

                        dialogPanel(screenWidth: geometry.size.width)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: viewModel.isVisible)
    }

    private var isLastLine: Bool {
        viewModel.index + 1 >= viewModel.lines.count
    }

    private func dialogPanel(screenWidth: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 14) {
            portraitStub(
                name: viewModel.leftName,
                colorHex: viewModel.leftColorHex,
                imageName: viewModel.leftProfileImage,
                isActive: viewModel.currentLine?.speaker == .left
            )

            centerDialog

            portraitStub(
                name: viewModel.rightName,
                colorHex: viewModel.rightColorHex,
                imageName: viewModel.rightProfileImage,
                isActive: viewModel.currentLine?.speaker == .right
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .frame(width: screenWidth * 2 / 3)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.cyan, lineWidth: 4)
        )
        // Location capsule — top edge, half outside
        .overlay(alignment: .top) {
            if !viewModel.locationName.isEmpty {
                Text(viewModel.locationName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(minWidth: 120)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color(red: 1.0, green: 0.2, blue: 0.8), lineWidth: 6))
                    .offset(y: -18)
            }
        }
        // Close capsule — bottom edge, half outside, only on last line and not loading
        .overlay(alignment: .bottom) {
            if isLastLine && !viewModel.isLoading {
                Button { viewModel.dismiss() } label: {
                    Text("Close")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .frame(minWidth: 120)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color(red: 1.0, green: 0.2, blue: 0.8), lineWidth: 6))
                }
                .offset(y: 18)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture { viewModel.next() }
    }

    private var centerDialog: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.secondary)
                    Text(L("Tuning in...", "正在连接..."))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(L("Please wait", "请稍候"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                VStack(alignment: textAlignment == .leading ? .leading : .trailing, spacing: 10) {
                    Text(speakerName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(speakerColor)
                        .frame(maxWidth: .infinity, alignment: textAlignment)

                    Text(viewModel.currentLine?.text ?? "")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: textAlignment)

                    if !isLastLine {
                        Text(L("Tap to continue", "轻触继续"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var speakerName: String {
        switch viewModel.currentLine?.speaker {
        case .left: return viewModel.leftName
        case .right: return viewModel.rightName
        case .none: return ""
        }
    }

    private var speakerColor: Color {
        let hex: String
        switch viewModel.currentLine?.speaker {
        case .left: hex = viewModel.leftColorHex
        case .right: hex = viewModel.rightColorHex
        case .none: hex = ""
        }
        return Color(hex: hex) ?? .secondary
    }

    private var textAlignment: Alignment {
        switch viewModel.currentLine?.speaker {
        case .left: return .leading
        case .right: return .trailing
        case .none: return .leading
        }
    }

    private func portraitStub(name: String, colorHex: String, imageName: String, isActive: Bool) -> some View {
        let npcColor = Color(hex: colorHex) ?? .cyan

        return ZStack(alignment: .bottom) {
            Image(imageName.isEmpty ? "Profile_Captain" : imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .opacity(1.0)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(npcColor.opacity(isActive ? 0.8 : 0.2), lineWidth: isActive ? 3 : 1.5)
                )

            Text(name)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(npcColor)
                .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 1)
                .padding(.bottom, 6)
        }
    }
}
