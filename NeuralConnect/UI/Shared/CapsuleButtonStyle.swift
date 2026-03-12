import SwiftUI

struct CapsuleButtonStyle: ButtonStyle {
    var color: Color = .cyan
    var variant: Variant = .outlined

    enum Variant {
        /// Primary action: dark semi-transparent background + colored stroke
        case outlined
        /// Secondary action: light semi-transparent background, no stroke
        case ghost
        /// Material blur background + colored stroke
        case material
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(background)
            .overlay(strokeOverlay)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }

    private var foregroundColor: AnyShapeStyle {
        switch variant {
        case .outlined: AnyShapeStyle(color)
        case .ghost: AnyShapeStyle(.white.opacity(0.6))
        case .material: AnyShapeStyle(.primary)
        }
    }

    private var horizontalPadding: CGFloat {
        switch variant {
        case .outlined: 20
        case .ghost: 16
        case .material: 24
        }
    }

    private var verticalPadding: CGFloat {
        switch variant {
        case .outlined: 10
        case .ghost: 8
        case .material: 8
        }
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .outlined:
            Capsule().fill(.black.opacity(0.5))
        case .ghost:
            Capsule().fill(.white.opacity(0.1))
        case .material:
            Capsule().fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var strokeOverlay: some View {
        switch variant {
        case .outlined:
            Capsule().stroke(color, lineWidth: 2)
        case .ghost:
            EmptyView()
        case .material:
            Capsule().stroke(color, lineWidth: 2)
        }
    }
}

extension ButtonStyle where Self == CapsuleButtonStyle {
    static var capsuleOutlined: CapsuleButtonStyle { .init() }

    static func capsuleOutlined(color: Color) -> CapsuleButtonStyle {
        .init(color: color, variant: .outlined)
    }

    static var capsuleGhost: CapsuleButtonStyle {
        .init(variant: .ghost)
    }

    static func capsuleMaterial(color: Color = .cyan) -> CapsuleButtonStyle {
        .init(color: color, variant: .material)
    }
}
