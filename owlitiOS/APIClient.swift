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
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()

    /// Performs a raw request against the backend, optionally including the JWT.
    /// Includes retry logic for reliability.
    func rawRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        token: String?
    ) async throws -> (Data, URLResponse) {
        let req = buildRequest(path: path, method: method, body: body, token: token)
        return try await retryRequest(request: req)
    }
    
    /// Retries the request up to `maxRetries` times with exponential backoff.
    private func retryRequest(request: URLRequest, maxRetries: Int = 3) async throws -> (Data, URLResponse) {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                if attempt > 0 {
                    print("🔄 Retry Attempt \(attempt + 1) for \(request.url?.path ?? "Unknown")")
                }
                
                let (data, response) = try await session.data(for: request)
                
                // If 5xx Server Error, treat as failure and retry
                if let httpResponse = response as? HTTPURLResponse, (500...599).contains(httpResponse.statusCode) {
                    print("⚠️ Server Error \(httpResponse.statusCode). Triggering retry.")
                    throw URLError(.badServerResponse)
                }
                
                return (data, response)
            } catch {
                lastError = error
                print("⚠️ Request failed (Attempt \(attempt + 1)/\(maxRetries)): \(error.localizedDescription)")
                
                // Don't sleep after the last attempt
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt)) // 1s, 2s, 4s
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? URLError(.unknown)
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
        data: Data?,
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
        data: Data?,
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
        if let data = data, !data.isEmpty {
            body.append("--\(boundary + lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\(lineBreak)")
            body.append("Content-Type: \(mimeType + lineBreak + lineBreak)")
            body.append(data)
            body.append(lineBreak)
        }
        
        // End Boundary
        body.append("--\(boundary)--\(lineBreak)")
        
        return body
    }

    // MARK: - Receipts
    func fetchReceipts(token: String) async throws -> [ReceiptData] {
        guard let url = URL(string: "\(baseURL)/api/receipts") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Debug
        print("Fetching Receipts URL: \(url.absoluteString)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ Error Fetching Receipts: \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([ReceiptData].self, from: data)
        } catch {
            print("Receipts decoding error: \(error)")
            throw URLError(.cannotDecodeContentData)
        }
    }
    
    // Fetch Enriched Line Items for Analytics (incl. normalized names)
    func fetchAnalyticsLineItems(token: String) async throws -> [LineItem] {
        guard let url = URL(string: "\(baseURL)/api/analytics/line-items") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 [APIClient] Raw Analytics Response (first 500 chars): \(jsonString.prefix(500))...")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            print("❌ [APIClient] Analytics Failed with Status \(httpResponse.statusCode). Body: \(body)")
            throw URLError(.badServerResponse)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([LineItem].self, from: data)
        } catch {
            print("❌ Analytics Line Items decoding error: \(error)")
            throw URLError(.cannotDecodeContentData)
        }
    }
    
    // MARK: - Insights
    func fetchMerchantSummary(merchant: String, token: String) async throws -> MerchantSummary {
        // Construct URL using URLComponents to handle query parameters correctly
        guard var components = URLComponents(url: baseURL.appendingPathComponent("/api/insights/merchant"), resolvingAgainstBaseURL: true) else {
            throw URLError(.badURL)
        }
        
        // Add Query Parameter
        components.queryItems = [
            URLQueryItem(name: "merchant_name", value: merchant)
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        // Create Request Manually to avoid buildRequest's appendingPathComponent issue with params
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Debug
        print("Fetching Merchant Summary URL: \(url.absoluteString)")
        
        let (data, response) = try await session.data(for: request)
        
        // Check for non-200 status
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
             print("❌ Error Fetching Summary: \(httpResponse.statusCode)")
             
             var errorDescription = "Unknown server error"
             if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let serverMessage = json["error"] as? String {
                 errorDescription = serverMessage
             } else {
                 errorDescription = String(data: data, encoding: .utf8) ?? "Unknown server error"
             }
             
             print("Body: \(errorDescription)")
             throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorDescription])
        }
        
        if let jsonString = String(data: data, encoding: .utf8) {
             print("DEBUG - Raw Summary JSON: \(jsonString)")
        }
        return try JSONDecoder().decode(MerchantSummary.self, from: data)
    }
    
    // MARK: - Filtered Merchants
    func fetchFilteredMerchants(token: String) async throws -> [String] {
        let (data, response) = try await rawRequest(path: "/api/merchants/filtered-list", token: token)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([String].self, from: data)
    }

    // MARK: - Client-Side Aggregation (Fallback)
    func fetchAllReceipts(token: String) async throws -> [ReceiptData] {
        let (data, response) = try await rawRequest(path: "/api/receipts", token: token)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([ReceiptData].self, from: data)
    }

    func deleteReceipt(receiptId: String, token: String) async throws {
        let body: [String: String] = ["id": receiptId]
        let bodyData = try JSONEncoder().encode(body)
        
        let (data, response) = try await rawRequest(path: "/api/receipts", method: "DELETE", body: bodyData, token: token)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            print("❌ Delete Receipt Failed: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Merchant Resolution
    // MARK: - Merchant Resolution
    func resolveMerchant(name: String, token: String) async throws -> MerchantResolution {
        // Construct URL safely
        guard var components = URLComponents(url: baseURL.appendingPathComponent("/api/merchants/resolve"), resolvingAgainstBaseURL: true) else {
            throw URLError(.badURL)
        }
        
        components.queryItems = [
            URLQueryItem(name: "name", value: name)
        ]
        
        guard let url = components.url else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        
        // Debug
        // print("🔍 resolving merchant: \(url.absoluteString)")
        
        // Retry logic wrapper manually or call session directly?
        // rawRequest wraps retryRequest. We can expose retryRequest or duplicate logic.
        // For simplicity and to reuse retry logic, let's make rawRequest support URLRequest or just call retryRequest provided we make it internal/accessible.
        // retryRequest is private.
        // I will just use session.data(for:) directly for now to minimize risk of breaking retryRequest visibility,
        // OR better: I can modify rawRequest to NOT append base URL if a full URL is passed? No.
        
        // Let's just use session.data for now, as these fallbacks are less critical than core sync.
        // Actually, retry is good. Let's inspect line 43. `private func retryRequest`.
        // I'll stick to simple session call for this fix to ensure correctness first.
        
        let (data, response) = try await session.data(for: req)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            // Log failure
            if let httpResponse = response as? HTTPURLResponse {
                print("❌ Resolve Failed: \(httpResponse.statusCode)")
            }
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(MerchantResolution.self, from: data)
    }
    
    // MARK: - Fetch Merchant Line Items (For Canonical Analytics)
    func fetchMerchantLineItems(merchantId: String, token: String) async throws -> [LineItem] {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("/api/insights/line-items"), resolvingAgainstBaseURL: true) else {
             throw URLError(.badURL)
        }
        
        components.queryItems = [
            URLQueryItem(name: "merchant_id", value: merchantId)
        ]
        
        guard let url = components.url else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🔍 Fetching line items: \(url.absoluteString)")
        
        let (data, response) = try await session.data(for: req)
         
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            print("❌ Fetch Line Items Failed: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw URLError(.badServerResponse)
        }
         
        return try JSONDecoder().decode([LineItem].self, from: data)
    }
    // MARK: - Global Analytics
    func fetchAnalyticsOverview(timeRange: String = "month", token: String) async throws -> AnalyticsOverview {
        guard let url = URL(string: "\(baseURL)/api/analytics/overview?time_range=\(timeRange)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(AnalyticsOverview.self, from: data)
        } catch {
            print("Analytics decoding error: \(error)")
            throw URLError(.cannotDecodeContentData)
        }
    }
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
