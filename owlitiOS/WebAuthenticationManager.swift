//
//  WebAuthenticationManager.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 15/11/2025.
//

import Foundation
import AuthenticationServices

/// A class to manage the `ASWebAuthenticationSession` flow.
class WebAuthenticationManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    
    /// The window that the web authentication session will be presented in.
    private var presentationWindow: UIWindow?

    /// Starts the web authentication flow.
    /// - Parameters:
    ///   - authURL: The URL to the authentication provider's login page.
    ///   - callbackURLScheme: The custom URL scheme that the app will respond to.
    ///   - completion: A closure that is called with the callback URL or an error.
    func start(authURL: URL, callbackURLScheme: String, completion: @escaping (Result<URL, Error>) -> Void) {
        // Find the key window to present the authentication session from.
        self.presentationWindow = UIApplication.shared.windows.first { $0.isKeyWindow }

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackURLScheme
        ) { callbackURL, error in
            if let error = error {
                // Check if the user cancelled the login flow.
                if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
                    print("👤 Web Auth: User cancelled.")
                    completion(.failure(WebAuthError.userCancelled))
                } else {
                    print("❌ Web Auth Error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            } else if let callbackURL = callbackURL {
                print("✅ Web Auth Success. Received callback: \(callbackURL)")
                completion(.success(callbackURL))
            } else {
                completion(.failure(WebAuthError.unknown))
            }
        }

        session.presentationContextProvider = self
        // Use an ephemeral session so logging out + logging back in shows the Google account picker again.
        session.prefersEphemeralWebBrowserSession = true
        session.start()
    }

    /// Tells the system which window to present the authentication session in.
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return presentationWindow ?? ASPresentationAnchor()
    }
}

/// Custom errors for web authentication.
enum WebAuthError: Error, LocalizedError {
    case userCancelled
    case unknown

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "The login process was cancelled."
        case .unknown:
            return "An unknown error occurred during web authentication."
        }
    }
}
