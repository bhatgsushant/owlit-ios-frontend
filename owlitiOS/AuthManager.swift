import Foundation
import SwiftUI
import Combine

@MainActor
class AuthManager: ObservableObject {
    // MARK: - Published Properties
    @Published var user: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    
    // The JWT received from the backend. Stored in memory.
    @Published private(set) var token: String?

    // Manager for the web-based authentication session.
    private var webAuthManager: WebAuthenticationManager?
    private let keychain = KeychainHelper.standard

    init() {
        if let persistedToken = keychain.read(service: KeychainHelper.service, account: KeychainHelper.account) {
            self.token = persistedToken
        }

        Task { await refreshUser() }
    }

    // MARK: - Web Authentication Flow
    
    /// Starts the web-based authentication process.
    func startWebAuth() {
        let authURL = APIClient.shared.googleOAuthURL()
        webAuthManager = WebAuthenticationManager()
        
        isLoading = true
        lastError = nil
        
        webAuthManager?.start(authURL: authURL, callbackURLScheme: "owlit") { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let callbackURL):
                    // The onOpenURL handler in the app will receive this URL,
                    // so we don't need to do anything further here.
                    print("✅ Web auth session succeeded, waiting for onOpenURL to handle token.")
                    Task {
                        await self.handleAuthCallback(url: callbackURL)
                    }
                case .failure(let error):
                    self.lastError = error.localizedDescription
                    print("❌ Web auth session failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Handles the callback URL received from the web authentication session.
    func handleAuthCallback(url: URL) async {
        print("AuthManager handling URL: \(url)")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            self.lastError = "Invalid callback URL received."
            return
        }

        // The token can be in a query parameter `?token=` or a URL fragment `#token=`
        let tokenValue = components.queryItems?.first(where: { $0.name == "token" })?.value ??
                         components.fragment?.split(separator: "=").last.map(String.init)

        if let token = tokenValue {
            print("🔑 Extracted token from URL.")
            await self.setTokenAndRefreshUser(token)
        } else {
            self.lastError = "Authentication callback did not contain a token."
            print("❌ Auth callback URL did not contain a token.")
        }
    }

    // MARK: - Token and User Management

    /// Saves the token and refreshes the user profile from the server.
    func setTokenAndRefreshUser(_ token: String) async {
        self.token = token
        persistToken(token)
        print("✅ Set backend token in memory.")
        await refreshUser()
    }

    /// Clears the session, token, and user data.
    func logout() {
        self.token = nil
        self.user = nil
        self.isAuthenticated = false
        self.lastError = nil
        persistToken(nil)
        print("🚪 Logged out and cleared session.")
    }

    /// Fetches the current user's profile from the `/api/user` endpoint.
    func refreshUser() async {
        if token == nil, let persisted = keychain.read(service: KeychainHelper.service, account: KeychainHelper.account) {
            self.token = persisted
        }

        guard let currentToken = self.token else {
            print("🔑 No token in memory, user is not logged in.")
            self.isAuthenticated = false
            self.user = nil
            return
        }
        
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let (responseData, response) = try await APIClient.shared.rawRequest(path: "/api/user", token: currentToken)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let errorBody = String(data: responseData, encoding: .utf8) ?? "Non-JSON error response"
                print("❌ /api/user non-2xx status: \(statusCode). Body: \(errorBody)")
                throw NSError(domain: "APIError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user profile. Status: \(statusCode)"])
            }
            
            let fetchedUser = try JSONDecoder().decode(User.self, from: responseData)
            self.user = fetchedUser
            self.isAuthenticated = true
            print("✅ Successfully refreshed user: \(fetchedUser.displayName ?? "Unknown")")
            
        } catch {
            print("❌ refreshUser failed: \(error.localizedDescription)")
            self.isAuthenticated = false
            self.user = nil
            self.token = nil // If the token is invalid, clear it.
            persistToken(nil)
            self.lastError = "Your session has expired. Please log in again."
        }
    }

    private func persistToken(_ token: String?) {
        if let token {
            keychain.save(token, service: KeychainHelper.service, account: KeychainHelper.account)
        } else {
            keychain.delete(service: KeychainHelper.service, account: KeychainHelper.account)
        }
    }
}

extension User {
    /// A computed property to safely construct a URL from the avatar string.
    var avatarURL: URL? {
        guard let avatarString = avatar, let url = URL(string: avatarString) else {
            return nil
        }
        return url
    }
}
