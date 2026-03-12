import SwiftUI

struct StorySequenceView: View {
    var onFinished: () -> Void

    @State private var currentIndex = 0
    @State private var displayedText = ""
    @State private var isAnimating = false
    @State private var animationTask: Task<Void, Never>?
    @State private var textOpacity: Double = 1.0
    @State private var tapEnabled = false

    private let slides = StoryContent.slides
    private let typewriterInterval: Duration = .milliseconds(70)

    private var isLastSlide: Bool { currentIndex == slides.count - 1 }

    var body: some View {
        ZStack {
            // Background image
            Color.black.ignoresSafeArea()

            if currentIndex < slides.count,
               let uiImage = UIImage(named: slides[currentIndex].imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .id(currentIndex)
                    .transition(.opacity)
            }

            if isLastSlide {
                // Last slide: centered text + bottom "开始游戏" button
                GeometryReader { geo in
                    VStack {
                        Spacer()
                        Text(displayedText)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.cyan)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: geo.size.width * 2 / 3, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .opacity(textOpacity)
                        Spacer()

                        Button {
                            onFinished()
                        } label: {
                            Text(L("Start Game", "开始游戏"))
                                .font(.system(size: 15, weight: .bold))
                        }
                        .buttonStyle(.capsuleOutlined)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(.easeIn(duration: 0.3), value: isAnimating)
                        .allowsHitTesting(!isAnimating)
                        .padding(.bottom, 60)
                    }
                }
            } else {
                // Darkening gradient at bottom for text readability
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 250)
                }
                .ignoresSafeArea()

                // Narration text — fixed width, left-aligned
                GeometryReader { geo in
                    VStack {
                        Spacer()
                        Text(displayedText)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.cyan)
                            .multilineTextAlignment(.leading)
                            .frame(width: geo.size.width * 2 / 3, alignment: .leading)
                            .frame(maxWidth: .infinity)
                            .opacity(textOpacity)
                            .padding(.bottom, 80)
                    }
                }

                // Skip button (top-right)
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            skipAll()
                        } label: {
                            Text(L("Skip", "跳过"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.blue)
                        }
                        .padding(.trailing, 48)
                        .padding(.top, 56)
                    }
                    Spacer()
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if tapEnabled { handleTap() }
        }
        .onAppear {
            startTypewriter()
            // Delay tap handling to prevent tap bleed-through from previous screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                tapEnabled = true
            }
        }
    }

    private func handleTap() {
        if isAnimating {
            // Show all text immediately
            animationTask?.cancel()
            if currentIndex < slides.count {
                displayedText = slides[currentIndex].localizedText
            }
            isAnimating = false
        } else {
            advanceSlide()
        }
    }

    private func advanceSlide() {
        let nextIndex = currentIndex + 1
        if nextIndex >= slides.count {
            // Last slide: do nothing — user must tap "开始游戏" button
            return
        } else {
            // Fade out text, then switch slide & fade in new typewriter
            withAnimation(.easeOut(duration: 0.25)) {
                textOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                currentIndex = nextIndex
                startTypewriter()
                withAnimation(.easeIn(duration: 0.25)) {
                    textOpacity = 1
                }
            }
        }
    }

    private func skipAll() {
        animationTask?.cancel()
        onFinished()
    }

    private func startTypewriter() {
        animationTask?.cancel()
        displayedText = ""
        guard currentIndex < slides.count else { return }
        let fullText = slides[currentIndex].localizedText
        isAnimating = true

        animationTask = Task {
            for char in fullText {
                if Task.isCancelled { return }
                displayedText.append(char)
                try? await Task.sleep(for: typewriterInterval)
            }
            if !Task.isCancelled {
                isAnimating = false
            }
        }
    }
}
