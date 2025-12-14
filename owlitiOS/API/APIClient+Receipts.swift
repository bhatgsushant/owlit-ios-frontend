import Foundation

struct ReceiptSaveResponse: Codable {
    let id: String?
    let receipt_url: String?
}

enum ReceiptScanMode: String {
    case receipt
    case document
}

extension APIClient {
    func scanReceipt(fileData: Data, filename: String, mimeType: String, highAccuracy: Bool, mode: ReceiptScanMode = .receipt, token: String?) async throws -> ReceiptDraft {
        var multipart = MultipartFormData()
        multipart.appendField(name: "scanMode", value: mode.rawValue)
        multipart.appendField(name: "highAccuracy", value: highAccuracy ? "true" : "false")
        multipart.appendFile(name: "file", filename: filename, mimeType: mimeType, data: fileData)

        var request = buildRequest(path: "/api/scan", method: "POST", body: nil, token: token)
        request.setValue("multipart/form-data; boundary=\(multipart.boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipart.finalize()

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let decoded = try JSONDecoder().decode(ReceiptDraft.self, from: data)
        return decoded
    }

    func saveReceipt(_ draft: ReceiptDraft, imageData: Data?, imageFilename: String?, imageMimeType: String?, token: String?) async throws -> ReceiptSaveResponse {
        var multipart = MultipartFormData()
        let payload = try draft.toServerPayload()
        multipart.appendField(name: "receiptData", value: String(data: payload, encoding: .utf8) ?? "{}")
        if let imageData, let imageFilename, let imageMimeType {
            multipart.appendFile(name: "receiptImage", filename: imageFilename, mimeType: imageMimeType, data: imageData)
        }

        var request = buildRequest(path: "/api/receipts", method: "POST", body: nil, token: token)
        request.setValue("multipart/form-data; boundary=\(multipart.boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipart.finalize()

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ReceiptSaveResponse.self, from: data)
    }

    func fetchReceipts(token: String) async throws -> [ReceiptRecord] {
        let request = buildRequest(path: "/api/receipts", method: "GET", body: nil, token: token)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode([ReceiptRecord].self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "APIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response."])
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}

// MARK: - Multipart Helper

struct MultipartFormData {
    let boundary = "Boundary-\(UUID().uuidString)"
    private var body = Data()

    mutating func appendField(name: String, value: String) {
        var field = "--\(boundary)\r\n"
        field += "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
        field += "\(value)\r\n"
        body.append(Data(field.utf8))
    }

    mutating func appendFile(name: String, filename: String, mimeType: String, data: Data) {
        var field = "--\(boundary)\r\n"
        field += "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
        field += "Content-Type: \(mimeType)\r\n\r\n"
        body.append(Data(field.utf8))
        body.append(data)
        body.append(Data("\r\n".utf8))
    }

    func finalize() -> Data {
        var finalData = body
        finalData.append(Data("--\(boundary)--\r\n".utf8))
        return finalData
    }
}
