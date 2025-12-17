//
//  APIClient.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 14/11/2025.
//

import Foundation

/// Request body for sending a Google ID token to the backend.
struct GoogleTokenRequest: Codable {
    let token: String
}

/// Expected response from backend authentication endpoints.
struct AuthResponse: Codable {
    let token: String
}

class APIClient {
    static let shared = APIClient()
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config)
    }()

    /// Performs a raw request against the backend, optionally including the JWT.
    func rawRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        token: String?
    ) async throws -> (Data, URLResponse) {
        let req = buildRequest(path: path, method: method, body: body, token: token)
        let (data, response) = try await session.data(for: req)
        return (data, response)
    }

    private init() {
        // This is now empty as we are removing in-memory state
    }

    // MARK: - BASE URL
    private let baseURL = URL(string: "https://owlit.onrender.com")!   // Production Server

    // MARK: - Auth URL (Redirect Flow)
    func googleOAuthURL(redirectPath: String? = nil) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("/auth/google"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [URLQueryItem(name: "platform", value: "ios")]
        if let redirectPath, !redirectPath.isEmpty { items.append(URLQueryItem(name: "redirect", value: redirectPath)) }
        components.queryItems = items
        return components.url!
    }

    // MARK: - TOKEN STORAGE
    // This now only saves to the secure keychain.
    public func setToken(_ token: String?) {
        if let token = token {
            KeychainHelper.standard.save(token, service: KeychainHelper.service, account: KeychainHelper.account)
        } else {
            KeychainHelper.standard.delete(service: KeychainHelper.service, account: KeychainHelper.account)
        }
    }

    // MARK: - Native Google Auth
    func authenticateWithGoogle(idToken: String) async throws -> AuthResponse {
        let url = baseURL.appendingPathComponent("/auth/google/ios")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["idToken": idToken]
        req.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Google Token Auth failed. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0). Body: \(errorBody)")
            throw NSError(domain: "APIError", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: "Failed to authenticate with server."])
        }

        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    // MARK: - Helper: Build Request
    func buildRequest(
        path: String,
        method: String,
        body: Data? = nil,
        token: String?
    ) -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        req.httpBody = body
        
        // --- START DEBUG LOGGING ---
        print("REQUEST HEADERS for \(path): \(req.allHTTPHeaderFields ?? [:])")
        // --- END DEBUG LOGGING ---
        
        return req
    }
    // MARK: - Multipart Upload
    func uploadRequest(
        path: String,
        method: String = "POST",
        data: Data,
        fileName: String,
        fieldName: String = "file",
        mimeType: String,
        parameters: [String: String]? = nil,
        token: String?
    ) async throws -> (Data, URLResponse) {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        
        // Generate Boundary
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Auth Header
        if let token = token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Construct Body
        req.httpBody = createMultipartBody(
            data: data,
            boundary: boundary,
            fileName: fileName,
            fieldName: fieldName,
            mimeType: mimeType,
            parameters: parameters
        )
        
        let (responseData, response) = try await session.data(for: req)
        return (responseData, response)
    }
    
    private func createMultipartBody(
        data: Data,
        boundary: String,
        fileName: String,
        fieldName: String,
        mimeType: String,
        parameters: [String: String]?
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        
        // Add Parameters
        if let parameters = parameters {
            for (key, value) in parameters {
                body.append("--\(boundary + lineBreak)")
                body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak + lineBreak)")
                body.append("\(value + lineBreak)")
            }
        }
        
        // Add File
        body.append("--\(boundary + lineBreak)")
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\(lineBreak)") 
        body.append("Content-Type: \(mimeType + lineBreak + lineBreak)")
        body.append(data)
        body.append(lineBreak)
        
        // End Boundary
        body.append("--\(boundary)--\(lineBreak)")
        
        return body
    }
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
