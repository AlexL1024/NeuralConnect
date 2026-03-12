import Foundation
import EverMemOSKit

/// Auth wrapper that adds a tenant header alongside the base auth provider.
private struct TenantAuth: AuthProvider {
    let base: AuthProvider
    let tenantId: String

    func applyAuth(to request: inout URLRequest) async {
        await base.applyAuth(to: &request)
        request.setValue(tenantId, forHTTPHeaderField: "X-Tenant-Id")
    }
}

public actor MemosService {
    private let client: EverMemOSClient
    private let metaClient: EverMemOSClient

    public init(config: Configuration) {
        self.client = EverMemOSClient(config: config)
        let metaConfig = Configuration(
            baseURL: config.baseURL,
            auth: config.auth,
            apiVersion: "v1",
            timeoutInterval: config.timeoutInterval,
            maxRetries: config.maxRetries,
            retryDelay: config.retryDelay,
            logLevel: config.logLevel
        )
        self.metaClient = EverMemOSClient(config: metaConfig)
    }

    public init(
        baseURL: URL,
        token: String,
        apiVersion: String = "v0",
        timeoutInterval: TimeInterval = 30,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        logLevel: Configuration.LogLevel = .error
    ) {
        let config = Configuration(
            baseURL: baseURL,
            auth: BearerTokenAuth(token: token),
            apiVersion: apiVersion,
            timeoutInterval: timeoutInterval,
            maxRetries: maxRetries,
            retryDelay: retryDelay,
            logLevel: logLevel
        )
        self.client = EverMemOSClient(config: config)
        let metaConfig = Configuration(
            baseURL: config.baseURL,
            auth: config.auth,
            apiVersion: "v1",
            timeoutInterval: config.timeoutInterval,
            maxRetries: config.maxRetries,
            retryDelay: config.retryDelay,
            logLevel: config.logLevel
        )
        self.metaClient = EverMemOSClient(config: metaConfig)
    }

    public init(profile: DeploymentProfile, baseURL: URL? = nil, token: String? = nil, tenantId: String? = nil) {
        let baseAuth: AuthProvider = profile.requiresAuth
            ? BearerTokenAuth(token: token ?? "")
            : NoAuth()
        let auth: AuthProvider = tenantId.map { TenantAuth(base: baseAuth, tenantId: $0) } ?? baseAuth
        let config = Configuration(profile: profile, baseURL: baseURL, auth: auth)
        self.init(config: config)
    }

    public func healthCheck() async throws -> HealthResponse {
        try await client.healthCheck()
    }

    public func memorize(_ request: MemorizeRequest) async throws -> MemorizeResponse {
        try await client.memorize(request)
    }

    public func fetchMemories(_ builder: FetchMemoriesBuilder) async throws -> FetchMemoriesResult {
        try await client.fetchMemories(builder)
    }

    public func searchMemories(_ builder: SearchMemoriesBuilder) async throws -> SearchResponse {
        try await client.searchMemories(builder)
    }

    public func deleteMemories(_ request: DeleteMemoriesRequest) async throws -> DeleteMemoriesResult {
        try await client.deleteMemories(request)
    }

    // MARK: - Conversation Meta (v1)

    public func createConversationMeta(_ request: ConversationMetaCreateRequest) async throws -> ConversationMetaData {
        try await metaClient.createConversationMeta(request)
    }

    public func getConversationMeta(groupId: String? = nil) async throws -> ConversationMetaData {
        try await metaClient.getConversationMeta(groupId: groupId)
    }

    public func patchConversationMeta(_ request: ConversationMetaPatchRequest) async throws -> PatchConversationMetaResult {
        try await metaClient.patchConversationMeta(request)
    }
}
