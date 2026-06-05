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
    let path: String
}


struct APIEvent: Decodable {
    let id: Int
    let device: String
    let seq: Int
    let type: String
}

// Parsed SSE event from /stream
struct ServerEvent {
    let id: Int
    let device: String
    let seq: Int
    let type: String
    let payload: [String: Any]
}

// MARK: - Client

final class APIClient {
    private var baseURL: String
    private var token: String
    private let session: URLSession
    private let streamSession: URLSession  // no resource timeout — for SSE

    init(baseURL: String, token: String) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.token = token
        self.session = URLSession(configuration: .default)
        let streamCfg = URLSessionConfiguration.default
        streamCfg.timeoutIntervalForResource = .infinity
        self.streamSession = URLSession(configuration: streamCfg)
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
        let body: [String: Any] = ["device": device, "seq": seq, "type": type, "payload": payload]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await session.data(for: req)
        guard let h = resp as? HTTPURLResponse, (200...299).contains(h.statusCode) else {
            throw APIError.badResponse((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    // MARK: - SSE Stream

    func streamEvents(clock: [String: Int]) -> AsyncThrowingStream<ServerEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard isConfigured else {
                    continuation.finish(throwing: APIError.notConfigured)
                    return
                }

                var components = URLComponents(string: baseURL + "/stream")!
                components.queryItems = clock.map {
                    URLQueryItem(name: $0.key, value: "\($0.value)")
                }
                guard let url = components.url else {
                    continuation.finish(throwing: APIError.notConfigured)
                    return
                }

                var req = URLRequest(url: url)
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                req.timeoutInterval = 300

                do {
                    let (bytes, response) = try await streamSession.bytes(for: req)
                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: APIError.badResponse(0))
                        return
                    }
                    guard (200...299).contains(http.statusCode) else {
                        continuation.finish(throwing: APIError.badResponse(http.statusCode))
                        return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        guard
                            let data     = json.data(using: .utf8),
                            let obj      = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                            let id       = (obj["id"]  as? NSNumber).map({ Int(truncating: $0) }),
                            let device   = obj["device"] as? String,
                            let seq      = (obj["seq"] as? NSNumber).map({ Int(truncating: $0) }),
                            let type     = obj["type"] as? String,
                            let payload  = obj["payload"] as? [String: Any]
                        else { continue }

                        continuation.yield(ServerEvent(id: id, device: device,
                                                        seq: seq, type: type, payload: payload))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
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
