import SwiftUI
import EverMemOSKit
import os.log

struct SetupView: View {
    var onComplete: () -> Void

    private static let gistURL = URL(string: "https://gist.githubusercontent.com/TonyLiangDesign/36fb07596d15f000f9e60b35789620c2/raw")!

    enum SetupStep: CaseIterable {
        case fetchingConfig
        case savingDeepSeek
        case savingEverMemOS
        case done

        var label: (en: String, zh: String) {
            switch self {
            case .fetchingConfig: return ("Fetching config…", "获取配置…")
            case .savingDeepSeek: return ("DeepSeek API Key", "DeepSeek API Key")
            case .savingEverMemOS: return ("EverMemOS Token", "EverMemOS Token")
            case .done: return ("All set!", "配置完成！")
            }
        }
    }

    @State private var currentStep: SetupStep?
    @State private var completedSteps: Set<SetupStep> = []
    @State private var errorMessage: String?
    @State private var isImporting = false
    @State private var showManualEntry = false

    var body: some View {
        ZStack {
            ParticleNetworkView(
                particleCount: 150,
                connectionDistance: 80,
                baseColor: .cyan
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Title
                VStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.cyan)
                        .shadow(color: .cyan.opacity(0.6), radius: 10)

                    Text(L("System Setup", "系统配置"))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)

                    Text(L("Configure API keys to enable AI dialogue", "配置 API 密钥以启用 AI 对话"))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                // Progress steps
                if isImporting || !completedSteps.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(SetupStep.allCases, id: \.self) { step in
                            stepRow(step)
                        }
                    }
                    .padding(.horizontal, 40)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Error
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // Buttons
                VStack(spacing: 16) {
                    if completedSteps.contains(.done) {
                        Button(action: onComplete) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.title3)
                                Text(L("START GAME", "开始游戏"))
                                    .font(.system(size: 18, weight: .bold))
                            }
                        }
                        .buttonStyle(.capsuleOutlined(color: .green))
                        .transition(.opacity.combined(with: .scale))
                    } else if !isImporting {
                        Button {
                            Task { await autoImport() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.title3)
                                Text(L("Auto Import", "自动导入"))
                                    .font(.system(size: 18, weight: .bold))
                            }
                        }
                        .buttonStyle(.capsuleOutlined)

                        Button {
                            showManualEntry = true
                        } label: {
                            Text(L("Manual Setup", "手动配置"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    } else {
                        ProgressView()
                            .tint(.cyan)
                    }
                }

                Spacer()
                    .frame(height: 20)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: completedSteps.count)
        .animation(.easeInOut(duration: 0.3), value: isImporting)
        .sheet(isPresented: $showManualEntry) {
            SettingsView(onSave: {
                if EverMemOSConfig.isConfigured {
                    SetupMode.current = .manual
                    completedSteps = Set(SetupStep.allCases)
                }
            })
        }
    }

    @ViewBuilder
    private func stepRow(_ step: SetupStep) -> some View {
        let isCompleted = completedSteps.contains(step)
        let isCurrent = currentStep == step

        HStack(spacing: 12) {
            ZStack {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .transition(.scale)
                } else if isCurrent {
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(width: 24, height: 24)

            Text(L(step.label.en, step.label.zh))
                .font(.system(size: 15, weight: isCurrent ? .bold : .regular, design: .monospaced))
                .foregroundStyle(isCompleted ? .green : isCurrent ? .cyan : .white.opacity(0.4))
        }
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
    }

    private func autoImport() async {
        isImporting = true
        errorMessage = nil

        // Step 1: Fetch config
        currentStep = .fetchingConfig
        do {
            let (data, _) = try await URLSession.shared.data(from: Self.gistURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let keys = json["keys"] as? [String: String] else {
                throw SetupError.invalidFormat
            }
            try await Task.sleep(for: .milliseconds(400))
            completedSteps.insert(.fetchingConfig)

            // Step 2: Save DeepSeek
            currentStep = .savingDeepSeek
            if let deepseekKey = keys["deepseek"], !deepseekKey.isEmpty {
                DeepSeekConfig.save(apiKey: deepseekKey, enabled: true)
            }
            try await Task.sleep(for: .milliseconds(400))
            completedSteps.insert(.savingDeepSeek)

            // Step 3: Save EverMemOS
            currentStep = .savingEverMemOS
            if let token = keys["evermemos_token"], !token.isEmpty {
                EverMemOSConfig.save(mode: .cloud, baseURL: EverMemOSConfig.cloudBaseURL.absoluteString, token: token)
            }
            try await Task.sleep(for: .milliseconds(400))
            completedSteps.insert(.savingEverMemOS)

            // Done
            currentStep = .done
            try await Task.sleep(for: .milliseconds(300))
            completedSteps.insert(.done)
            currentStep = nil

            SetupMode.current = .auto
            NHLogger.system.info("[Setup] Auto-import completed successfully")
        } catch {
            NHLogger.system.error("[Setup] Auto-import failed: \(error)")
            errorMessage = L("Import failed: \(error.localizedDescription)", "导入失败: \(error.localizedDescription)")
            currentStep = nil
        }

        isImporting = false
    }

    enum SetupError: LocalizedError {
        case invalidFormat

        var errorDescription: String? {
            L("Invalid config format", "配置格式无效")
        }
    }
}
