import Foundation

// MARK: - API Errors

enum APIError: Error, LocalizedError {
    case notConfigured
    case badResponse(Int)
    case decode(Error)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:      return "Server URL not configured. Go to Settings."
        case .badResponse(let c): return "Server returned \(c)"
        case .decode(let e):      return "Decode error: \(e)"
        case .network(let e):     return e.localizedDescription
        }
    }
}

// MARK: - Wire types (match server JSON)

struct APIBook: Decodable {
    let id: String
    let title: String
    let author: String
    let created_at: String
}

struct APIChunk: Decodable {
    let index: Int
    let title: String
    let html: String
}

struct APIEvent: Decodable {
    let id: Int
    let device: String
    let seq: Int
    let type: String
}

// MARK: - Client

final class APIClient {
    private var baseURL: String
    private var token: String
    private let session: URLSession

    init(baseURL: String, token: String) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.token = token
        self.session = URLSession(configuration: .default)
    }

    func configure(baseURL: String, token: String) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.token = token
    }

    var isConfigured: Bool { !baseURL.isEmpty && !token.isEmpty }

    // MARK: - Books

    func fetchBooks() async throws -> [APIBook] {
        try await get("/books")
    }

    func importBook(title: String, author: String, fileURL: URL) async throws -> APIBook {
        guard isConfigured else { throw APIError.notConfigured }
        var req = try urlRequest("/books/import")
        let boundary = "Boundary-\(UUID().uuidString)"
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        field("title", title)
        field("author", author)

        let fileData = try Data(contentsOf: fileURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/epub+zip\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        return try await send(req)
    }

    func fetchChunks(bookId: String) async throws -> [APIChunk] {
        try await get("/books/\(bookId)/chunks")
    }

    // MARK: - Events

    func postEvent(device: String, seq: Int, type: String, payload: [String: Any]) async throws {
        guard isConfigured else { return }
        var req = try urlRequest("/events")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["device": device, "seq": seq, "type": type, "payload": payload]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await session.data(for: req)
        guard let h = resp as? HTTPURLResponse, (200...299).contains(h.statusCode) else {
            throw APIError.badResponse((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    func ping() async throws {
        _ = try await get("/health") as [String: String]
    }

    // MARK: - Helpers

    private func urlRequest(_ path: String) throws -> URLRequest {
        guard isConfigured, let url = URL(string: baseURL + path) else {
            throw APIError.notConfigured
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30
        return req
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let req = try urlRequest(path)
        return try await send(req)
    }

    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        do {
            let (data, resp) = try await session.data(for: req)
            guard let h = resp as? HTTPURLResponse else { throw APIError.badResponse(0) }
            guard (200...299).contains(h.statusCode) else { throw APIError.badResponse(h.statusCode) }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch { throw APIError.decode(error) }
        } catch let e as APIError { throw e }
        catch { throw APIError.network(error) }
    }
}
