import SwiftUI
import os.log
import EverMemOSKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var deploymentMode: DeploymentProfile
    @State private var cloudBaseURL: String
    @State private var cloudToken: String
    @State private var localBaseURL: String
    @State private var deepSeekEnabled: Bool
    @State private var deepSeekAPIKey: String
    @State private var saved = false
    @State private var showDeleteConfirm = false
    @State private var deleteStatus: String?
    @State private var isDeleting = false
    @State private var language: GameLanguage
    @State private var testStatus: String?
    @State private var isTesting = false
    @State private var showAutoPlayAlert = false

    var onStartAutoPlay: (() -> Void)?

    var onSave: (() -> Void)?
    var onReplayIntro: (() -> Void)?

    private var appleIntelligenceAvailable: Bool {
        AppleFoundationModelsDialogueProvider.status() == .available
    }

    init(onSave: (() -> Void)? = nil, onReplayIntro: (() -> Void)? = nil, onStartAutoPlay: (() -> Void)? = nil) {
        self.onSave = onSave
        self.onReplayIntro = onReplayIntro
        self.onStartAutoPlay = onStartAutoPlay
        _deploymentMode = State(initialValue: EverMemOSConfig.deploymentMode)
        _cloudBaseURL = State(initialValue: EverMemOSConfig.cloudBaseURL.absoluteString)
        _cloudToken = State(initialValue: EverMemOSConfig.cloudToken)
        _localBaseURL = State(initialValue: EverMemOSConfig.localBaseURL.absoluteString)
        _deepSeekEnabled = State(initialValue: DeepSeekConfig.isEnabled)
        _deepSeekAPIKey = State(initialValue: DeepSeekConfig.apiKey)
        _language = State(initialValue: LanguageManager.shared.current)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L("Language", "语言")) {
                    Picker(L("Language", "语言"), selection: $language) {
                        Text("English").tag(GameLanguage.english)
                        Text("中文").tag(GameLanguage.chinese)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: language) { _, newValue in
                        LanguageManager.shared.current = newValue
                    }
                }

                Section {
                        Toggle(L("Use DeepSeek", "使用 DeepSeek"), isOn: $deepSeekEnabled)
                        if deepSeekEnabled {
                            LabeledContent("API Key") {
                                SecureField(L("Enter API Key", "输入 API Key"), text: $deepSeekAPIKey)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    } header: {
                        Text(L("AI Dialogue Engine", "AI 对话引擎"))
                    } footer: {
                        Text(appleIntelligenceAvailable
                             ? L("Enable DeepSeek for the best dialogue experience. When disabled, Apple Intelligence (on-device) will be used instead.",
                                 "开启 DeepSeek 可获得最佳对话体验。关闭后将使用 Apple Intelligence（设备端）生成对话。")
                             : L("Enable DeepSeek for the best dialogue experience. Your device does not support Apple Intelligence, so DeepSeek is required for AI dialogue.",
                                 "开启 DeepSeek 可获得最佳对话体验。您的设备不支持 Apple Intelligence，需要开启 DeepSeek 才能使用 AI 对话。"))
                    }

                    Section("EverMemOS") {
                        Picker(L("Mode", "模式"), selection: $deploymentMode) {
                            Text("Cloud").tag(DeploymentProfile.cloud)
                            Text("Local").tag(DeploymentProfile.local)
                        }
                        .pickerStyle(.segmented)

                        if deploymentMode == .cloud {
                            LabeledContent("Base URL") {
                                TextField("https://api.evermind.ai", text: $cloudBaseURL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.trailing)
                            }
                            LabeledContent("Token") {
                                SecureField(L("Enter token", "输入 token"), text: $cloudToken)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.trailing)
                            }
                        } else {
                            LabeledContent("Base URL") {
                                TextField("http://localhost:1995", text: $localBaseURL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.trailing)
                            }
                            Button {
                                testConnection()
                            } label: {
                                HStack {
                                    if isTesting {
                                        ProgressView()
                                            .padding(.trailing, 4)
                                    }
                                    Text(isTesting ? "Testing..." : "Test Connection")
                                }
                            }
                            .disabled(isTesting || localBaseURL.isEmpty)

                            if let status = testStatus {
                                Text(status)
                                    .font(.caption)
                                    .foregroundStyle(status.contains("✓") ? .green : .red)
                            }
                        }
                    }

                    Section {
                        Button {
                            DeepSeekConfig.save(apiKey: deepSeekAPIKey, enabled: deepSeekEnabled)
                            EverMemOSConfig.save(
                                mode: deploymentMode,
                                baseURL: deploymentMode == .cloud ? cloudBaseURL : localBaseURL,
                                token: cloudToken
                            )
                            saved = true
                            onSave?()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text(saved ? L("Saved", "已保存") : L("Save & Reconnect", "保存并重连"))
                                Spacer()
                            }
                        }
                    }

                if let onReplayIntro {
                    Section(L("Story", "剧情")) {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onReplayIntro()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label(L("Replay Intro", "重看开场"), systemImage: "film")
                                Spacer()
                            }
                        }
                    }
                }

                #if DEBUG
                Section(L("Debug", "调试")) {
                    Button {
                        showAutoPlayAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Label(L("Start Auto Play", "启动自动播放"), systemImage: "play.circle.fill")
                            Spacer()
                        }
                    }
                }
                #endif

                Section(L("Data Management", "数据管理")) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            if isDeleting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(deleteStatus ?? L("Delete All NPC Memories", "清空所有 NPC 记忆"))
                            Spacer()
                        }
                    }
                    .disabled(isDeleting || !EverMemOSConfig.isConfigured)
                }
            }
            .navigationTitle(L("Settings", "设置"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Close", "关闭")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .alert(L("Confirm Delete", "确认清空"), isPresented: $showDeleteConfirm) {
            Button(L("Delete", "清空"), role: .destructive) {
                deleteAllMemories()
            }
            Button(L("Cancel", "取消"), role: .cancel) {}
        } message: {
            Text(L("This will delete all NPC memory data from EverMemOS. This action cannot be undone.", "将删除 EverMemOS 中所有 NPC 的记忆数据，此操作不可撤销。"))
        }
        .alert(L("Warning", "警告"), isPresented: $showAutoPlayAlert) {
            Button(L("Start", "启动"), role: .destructive) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onStartAutoPlay?()
                }
            }
            Button(L("Cancel", "取消"), role: .cancel) {}
        } message: {
            Text(L("Auto Play will consume a large amount of API tokens. Continue?", "自动播放会消耗大量 API Token，是否继续？"))
        }
    }

    private func deleteAllMemories() {
        guard let service = EverMemOSConfig.buildService() else { return }
        isDeleting = true
        deleteStatus = nil

        Task {
            do {
                let npcIds = NPCRoster.all.map(\.id)
                var totalDeleted = 0
                for npcId in npcIds {
                    let request = DeleteMemoriesRequest(userId: npcId)
                    let result = try await service.deleteMemories(request)
                    totalDeleted += result.count
                    NHLogger.system.info("[Settings] Deleted \(result.count) memories for \(npcId)")
                }
                await MainActor.run {
                    isDeleting = false
                    GameState.clearRelationships()
                    deleteStatus = L("Deleted \(totalDeleted) memories", "已清空 \(totalDeleted) 条记忆")
                    onSave?()
                }
            } catch {
                NHLogger.system.error("[Settings] Delete memories failed: \(error)")
                await MainActor.run {
                    isDeleting = false
                    deleteStatus = L("Delete failed: \(error)", "清空失败: \(error)")
                }
            }
        }
    }

    private func testConnection() {
        guard let url = URL(string: localBaseURL) else {
            testStatus = "✗ Invalid URL"
            return
        }
        isTesting = true
        testStatus = nil

        Task {
            do {
                let healthURL = url.appendingPathComponent("/health")
                var request = URLRequest(url: healthURL, timeoutInterval: 3)
                request.httpMethod = "GET"
                let (_, response) = try await URLSession.shared.data(for: request)
                await MainActor.run {
                    isTesting = false
                    if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        testStatus = "✓ Connected"
                    } else {
                        testStatus = "✗ Server returned error"
                    }
                }
            } catch let error as URLError {
                await MainActor.run {
                    isTesting = false
                    switch error.code {
                    case .cannotConnectToHost, .cannotFindHost:
                        testStatus = "✗ Cannot connect to server"
                    case .timedOut:
                        testStatus = "✗ Connection timed out"
                    default:
                        testStatus = "✗ Connection failed"
                    }
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testStatus = "✗ Connection failed"
                }
            }
        }
    }
}
