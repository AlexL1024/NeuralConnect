import Foundation
import os.log

private let apiLog = Logger(subsystem: "com.MrPolpo.NeuralConnect", category: "DeepSeekAPI")

/// Shared DeepSeek API caller for dialogue, summary, and observation generation.
enum DeepSeekAPI {
    private static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
    private static let model = "deepseek-chat"

    /// Send a chat completion request and return the text content.
    static func generate(system: String, user: String, maxTokens: Int = 300, temperature: Double = 1.0) async throws -> String {
        let apiKey = DeepSeekConfig.apiKey
        guard !apiKey.isEmpty else { throw DeepSeekAPIError.notConfigured }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "temperature": temperature,
            "max_tokens": maxTokens
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8>"
            apiLog.error("[DeepSeekAPI] HTTP \(code) — body: \(bodyPreview)")
            throw DeepSeekAPIError.httpError(code)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8>"
            apiLog.error("[DeepSeekAPI] Invalid response structure — body: \(bodyPreview)")
            throw DeepSeekAPIError.invalidResponse
        }

        let result = content.trimmingCharacters(in: .whitespacesAndNewlines)
        apiLog.debug("[DeepSeekAPI] Raw response (\(result.count) chars): \(result)")
        return result
    }
}

enum DeepSeekAPIError: Error {
    case notConfigured
    case httpError(Int)
    case invalidResponse
}
