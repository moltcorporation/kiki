import AuthenticationServices
import CryptoKit
import Foundation

/// Signs the runner in with Apple and keeps the Better Auth session token
/// in the Keychain.
@Observable
final class AuthService {
    private(set) var userID: String? = Keychain.userID
    private(set) var email: String?

    var isSignedIn: Bool { userID != nil }

    private let api = APIClient.shared
    /// Raw nonce for the in-flight Apple request; its SHA-256 goes to Apple.
    private var appleNonce: String?

    init() {
        #if DEBUG
        // Simulator testing: Sign in with Apple needs a real Apple ID, so a
        // session can be injected at launch (compiled out of release builds).
        let env = ProcessInfo.processInfo.environment
        if let token = env["KIKI_DEBUG_SESSION_TOKEN"], let id = env["KIKI_DEBUG_USER_ID"] {
            Keychain.sessionToken = token
            Keychain.userID = id
            userID = id
        }
        #endif
    }

    // MARK: Apple

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        appleNonce = nonce
        request.requestedScopes = [.email, .fullName]
        request.nonce = Self.sha256(nonce)
    }

    func completeApple(_ result: Result<ASAuthorization, Error>) async throws -> Bool {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return false }
            throw error
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                throw APIError.unexpected
            }
            try await signInWithIDToken(token: token, nonce: appleNonce)
            await recordPendingConsent()
            if let codeData = credential.authorizationCode,
               let code = String(data: codeData, encoding: .utf8) {
                await registerAppleAuthorization(code)
            }
            return true
        }
    }

    /// Lets the server exchange Apple's one-time code for a refresh token, so
    /// the authorization can be revoked if the account is deleted. Non-fatal.
    private func registerAppleAuthorization(_ code: String) async {
        struct Body: Encodable { let authorizationCode: String }
        do {
            let _: Empty = try await api.post("api/me/apple-token", Body(authorizationCode: code))
        } catch {
            Analytics.captureError(error, context: ["step": "apple_token_exchange"])
        }
    }

    // MARK: Consent

    private static let pendingConsentKey = "consent.pendingAt"

    /// Remembers that the user agreed to the Terms and Privacy Policy, so it
    /// can be recorded once they're signed in (and retried if that fails).
    func noteConsent() {
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: Self.pendingConsentKey)
    }

    /// Sends a pending agreement to the server's append-only consent log.
    /// Safe to call repeatedly; keeps it pending until the server has it.
    func recordPendingConsent() async {
        let agreedAt = UserDefaults.standard.double(forKey: Self.pendingConsentKey)
        guard agreedAt > 0, isSignedIn else { return }
        struct Body: Encodable { let version: String; let acceptedAt: String; let appVersion: String }
        let body = Body(
            version: Config.legalVersion,
            acceptedAt: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: agreedAt)),
            appVersion: Bundle.main.appVersion
        )
        do {
            let _: Empty = try await api.post("api/me/consent", body)
            UserDefaults.standard.removeObject(forKey: Self.pendingConsentKey)
        } catch {
            Analytics.captureError(error, context: ["step": "record_consent"])
        }
    }

    // MARK: Session

    func signOut() async {
        if isSignedIn {
            _ = try? await api.authRequest("POST", "api/auth/sign-out", body: Empty())
        }
        clearSession()
    }

    func deleteAccount() async throws {
        try await api.delete("api/me")
        Analytics.track("account_deleted")
        clearSession()
    }

    /// Clears local credentials without calling the server (e.g. after a 401).
    func clearSession() {
        Keychain.clear()
        userID = nil
        email = nil
        Identity.reset()
    }

    private func signInWithIDToken(token: String, nonce: String?) async throws {
        struct IDToken: Encodable { let token: String; let nonce: String? }
        struct Body: Encodable { let provider = "apple"; let idToken: IDToken }
        let (data, response) = try await api.authRequest(
            "POST", "api/auth/sign-in/social",
            body: Body(idToken: IDToken(token: token, nonce: nonce))
        )
        guard response.statusCode == 200 else { throw APIError.unexpected }
        try complete(data: data, response: response)
    }

    private func complete(data: Data, response: HTTPURLResponse) throws {
        struct SessionBody: Decodable {
            struct User: Decodable { let id: String; let email: String?; let createdAt: Date? }
            let user: User
        }
        guard let token = response.value(forHTTPHeaderField: "set-auth-token"),
              let body = try? api.decode(SessionBody.self, from: data)
        else { throw APIError.unexpected }

        Keychain.sessionToken = token
        Keychain.userID = body.user.id
        userID = body.user.id
        email = body.user.email
        Identity.identify(userID: body.user.id, email: body.user.email)
        let isNewUser = body.user.createdAt.map { Date.now.timeIntervalSince($0) < 120 } ?? false
        Analytics.track("signed_in", ["method": "apple", "new_user": isNewUser])
        if isNewUser { Attribution.completedRegistration(method: "apple") }
    }

    // MARK: Nonce helpers

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
