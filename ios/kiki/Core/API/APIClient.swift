import Foundation

enum APIError: LocalizedError, Equatable {
    case unauthorized
    case subscriptionRequired
    case offline
    case server(code: String, message: String)
    case unexpected

    var errorDescription: String? {
        switch self {
        case .unauthorized: "Please sign in again."
        case .subscriptionRequired: "This needs an active Kiki subscription."
        case .offline: "You're offline. We'll sync when you're back online."
        case .server(_, let message): message
        case .unexpected: "Something went wrong. Please try again."
        }
    }

    var isRetryable: Bool { self == .offline || self == .unexpected }
}

/// Thin JSON client for the Kiki API with bearer auth and retries.
final class APIClient {
    static let shared = APIClient()

    /// Called when the server rejects our session so the app can sign out.
    var onUnauthorized: (() -> Void)?

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
                return date
            }
            if let date = try? Date(string, strategy: .iso8601) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(string)"))
        }
    }

    // MARK: Requests

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await send("GET", path, query: query, body: Optional<Empty>.none)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, _ body: B) async throws -> T {
        try await send("POST", path, body: body)
    }

    func put<T: Decodable, B: Encodable>(_ path: String, _ body: B) async throws -> T {
        try await send("PUT", path, body: body)
    }

    func patch<T: Decodable, B: Encodable>(_ path: String, _ body: B) async throws -> T {
        try await send("PATCH", path, body: body)
    }

    func delete(_ path: String) async throws {
        let _: Empty = try await send("DELETE", path, body: Optional<Empty>.none)
    }

    /// Raw request for auth endpoints that return a session token header.
    func authRequest<B: Encodable>(_ method: String, _ path: String, query: [String: String] = [:], body: B?) async throws -> (Data, HTTPURLResponse) {
        let request = try makeRequest(method, path, query: query, body: body, authenticated: false)
        return try await perform(request, retries: 1)
    }

    private func send<T: Decodable, B: Encodable>(
        _ method: String,
        _ path: String,
        query: [String: String] = [:],
        body: B?
    ) async throws -> T {
        let request = try makeRequest(method, path, query: query, body: body, authenticated: true)
        let (data, response) = try await perform(request, retries: 3)

        switch response.statusCode {
        case 200..<300:
            if T.self == Empty.self || data.isEmpty { return Empty() as! T }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                Analytics.captureError(error, context: ["path": path])
                throw APIError.unexpected
            }
        case 401:
            onUnauthorized?()
            throw APIError.unauthorized
        case 402:
            throw APIError.subscriptionRequired
        default:
            let payload = try? decoder.decode(ErrorPayload.self, from: data)
            if let payload {
                throw APIError.server(code: payload.error.code, message: payload.error.message)
            }
            throw APIError.unexpected
        }
    }

    private func makeRequest<B: Encodable>(
        _ method: String,
        _ path: String,
        query: [String: String],
        body: B?,
        authenticated: Bool
    ) throws -> URLRequest {
        var components = URLComponents(url: Config.apiBaseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated, let token = Keychain.sessionToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// Retries network failures and 5xx responses with exponential backoff.
    private func perform(_ request: URLRequest, retries: Int) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        while true {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw APIError.unexpected }
                if http.statusCode >= 500, attempt < retries {
                    attempt += 1
                    try await backoff(attempt)
                    continue
                }
                return (data, http)
            } catch let error as URLError {
                if error.code == .cancelled { throw CancellationError() }
                let offline: Set<URLError.Code> = [.notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff]
                if offline.contains(error.code) { throw APIError.offline }
                if attempt < retries {
                    attempt += 1
                    try await backoff(attempt)
                    continue
                }
                throw APIError.unexpected
            }
        }
    }

    private func backoff(_ attempt: Int) async throws {
        let seconds = 0.5 * pow(2, Double(attempt - 1)) + Double.random(in: 0...0.25)
        try await Task.sleep(for: .seconds(seconds))
    }

    func encode<B: Encodable>(_ value: B) throws -> Data { try encoder.encode(value) }
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T { try decoder.decode(type, from: data) }
}

struct Empty: Codable, Sendable {}

private struct ErrorPayload: Decodable {
    struct Body: Decodable {
        let code: String
        let message: String
    }
    let error: Body
}
