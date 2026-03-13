import SwiftUI

enum AppPhase {
    case splash, start, setup, story, game
}

@main
struct NeuralConnectApp: App {
    #if DEBUG && targetEnvironment(simulator)
    @State private var phase: AppPhase = .game
    #else
    @State private var phase: AppPhase = .splash
    #endif

    var body: some Scene {
        WindowGroup {
            Group {
                switch phase {
                case .splash:
                    SplashView {
                        withAnimation { phase = .start }
                    }
                case .start:
                    StartScreenView {
                        // Skip setup if keys already configured
                        if EverMemOSConfig.isConfigured {
                            withAnimation { phase = .story }
                        } else {
                            withAnimation { phase = .setup }
                        }
                    }
                case .setup:
                    SetupView {
                        withAnimation { phase = .story }
                    }
                case .story:
                    StorySequenceView {
                        withAnimation { phase = .game }
                    }
                case .game:
                    GameContainerView(onReplayIntro: {
                        withAnimation { phase = .story }
                    })
                }
            }
            .ignoresSafeArea()
            .persistentSystemOverlays(.hidden)
            .statusBarHidden()
            .preferredColorScheme(.dark)
        }
    }
}
