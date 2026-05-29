import Foundation
import AuthenticationServices
import AppKit
import CryptoKit

@MainActor
class GoogleCalendarManager: NSObject, ObservableObject {
    static let shared = GoogleCalendarManager()

    @Published var isConnected: Bool = false
    @Published var connectedEmail: String? = nil
    @Published var isAuthenticating: Bool = false
    @Published var errorMessage: String? = nil

    private let scope = "https://www.googleapis.com/auth/calendar"

    private func reverseScheme(for clientID: String) -> String {
        let prefix = clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(prefix)"
    }

    private func redirectURI(for clientID: String) -> String {
        "\(reverseScheme(for: clientID)):/"
    }

    private var authSession: ASWebAuthenticationSession?
    private var pendingCodeVerifier: String?

    private override init() {
        super.init()
        checkConnectionStatus()
    }

    func checkConnectionStatus() {
        isConnected    = Keychain.load(for: "google_refresh_token") != nil
        connectedEmail = Keychain.load(for: "google_calendar_email")
    }

    func connect(clientID: String) {
        guard !clientID.isEmpty else {
            errorMessage = "Enter your Client ID first."
            return
        }

        Keychain.save(clientID, for: "google_client_id")
        errorMessage = nil

        let codeVerifier  = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        pendingCodeVerifier = codeVerifier

        let scheme      = reverseScheme(for: clientID)
        let redirectURI = self.redirectURI(for: clientID)

        guard var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth") else {
            errorMessage = "Failed to build authorization URL."
            return
        }
        components.queryItems = [
            URLQueryItem(name: "client_id",             value: clientID),
            URLQueryItem(name: "redirect_uri",          value: redirectURI),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "scope",                 value: scope),
            URLQueryItem(name: "access_type",           value: "offline"),
            URLQueryItem(name: "prompt",                value: "consent"),
            URLQueryItem(name: "code_challenge",        value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let authURL = components.url else {
            errorMessage = "Failed to build authorization URL."
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        isAuthenticating = true
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: scheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAuthenticating = false
                if let error {
                    self.pendingCodeVerifier = nil
                    if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }
                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "code" })?.value,
                      let verifier = self.pendingCodeVerifier
                else {
                    self.errorMessage = "No authorization code received."
                    self.pendingCodeVerifier = nil
                    return
                }
                self.pendingCodeVerifier = nil
                await self.exchangeCode(code, clientID: clientID, codeVerifier: verifier, redirectURI: redirectURI)
            }
        }
        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = true
        authSession?.start()
    }

    func disconnect() {
        Keychain.delete(for: "google_refresh_token")
        Keychain.delete(for: "google_calendar_email")
        Keychain.delete(for: "google_client_id")
        isConnected    = false
        connectedEmail = nil
        errorMessage   = nil
    }

    // MARK: - PKCE helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Private

    private func exchangeCode(_ code: String, clientID: String, codeVerifier: String, redirectURI: String) async {
        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else {
            errorMessage = "Token exchange failed."
            return
        }
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params: [String: String] = [
            "code":          code,
            "client_id":     clientID,
            "code_verifier": codeVerifier,
            "redirect_uri":  redirectURI,
            "grant_type":    "authorization_code",
        ]
        var formChars = CharacterSet.urlQueryAllowed
        formChars.remove(charactersIn: "+&=")
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: formChars) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            errorMessage = "Token exchange network error: \(error.localizedDescription)"
            return
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            // Still parse the body below — Google returns a JSON error object on
            // 4xx that the error/error_description handling can surface — but if
            // the body isn't usable JSON, report the status code.
            if (try? JSONSerialization.jsonObject(with: data)) == nil {
                errorMessage = "Token exchange failed (HTTP \(http.statusCode))."
                return
            }
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            errorMessage = "Token exchange failed: unexpected response."
            return
        }

        if let err = json["error"] as? String {
            errorMessage = json["error_description"] as? String ?? err
            return
        }

        guard let refreshToken = json["refresh_token"] as? String else {
            errorMessage = "No refresh token returned."
            return
        }

        Keychain.save(refreshToken, for: "google_refresh_token")

        if let accessToken = json["access_token"] as? String {
            await fetchUserEmail(accessToken: accessToken)
        }

        isConnected = true
    }

    private func fetchUserEmail(accessToken: String) async {
        guard let userinfoURL = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo") else { return }
        var request = URLRequest(url: userinfoURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let email = json["email"] as? String
        else { return }
        Keychain.save(email, for: "google_calendar_email")
        connectedEmail = email
    }
}

extension GoogleCalendarManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.windows.first(where: { $0.isVisible }) ?? ASPresentationAnchor()
    }
}
