import SwiftUI

struct StartScreenView: View {
    var onStart: () -> Void

    @State private var language: GameLanguage = LanguageManager.shared.current

    var body: some View {
        ZStack {
            ParticleNetworkView(
                particleCount: 200,
                connectionDistance: 100,
                baseColor: .cyan
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 8) {
                    Text("NEURAL CONNECT")
                        .font(.system(size: 44, weight: .black, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .white, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .cyan.opacity(0.8), radius: 12)
                        .shadow(color: .cyan.opacity(0.4), radius: 30)

                    Text(language == .english ? "Connect the memories. Find the truth." : "连接记忆，揭开真相。")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                // Start button
                Button(action: onStart) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.title3)
                        Text(language == .english ? "START" : "开始")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .buttonStyle(.capsuleOutlined)

                // Language picker
                Picker("Language", selection: $language) {
                    Text("English").tag(GameLanguage.english)
                    Text("中文").tag(GameLanguage.chinese)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .onChange(of: language) { _, newValue in
                    LanguageManager.shared.current = newValue
                }

                Spacer()
                    .frame(height: 20)
            }
        }
    }
}
