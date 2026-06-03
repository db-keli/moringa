import Foundation
import SQLite3

// MARK: - Server Models

struct Book: Codable {
    let id: String
    let title: String
    let author: String
    let createdAt: String
    enum CodingKeys: String, CodingKey {
        case id, title, author
        case createdAt = "created_at"
    }
}

struct SyncEvent: Codable {
    let id: Int?
    let device: String
    let seq: Int
    let type: String
    let payload: [String: String]?
    let createdAt: String?
    enum CodingKeys: String, CodingKey {
        case id, device, seq, type, payload
        case createdAt = "created_at"
    }
}

struct Chunk: Codable {
    let index: Int
    let title: String
    let content: String
}

struct ErrorResponse: Codable {
    let error: String
}

struct EventRequest: Codable {
    let device: String
    let seq: Int
    let type: String
    let payload: [String: String]
}

// MARK: - Server Client

class MoringaClient {
    let baseURL: URL
    let token: String

    init(baseURL: String, token: String) {
        self.baseURL = URL(string: baseURL)!
        self.token = token
    }

    func request<T: Codable>(_ method: String, _ path: String, body: Data? = nil) async throws -> T
    {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            let err = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw URLError(
                .init(rawValue: http.statusCode),
                userInfo: [NSLocalizedDescriptionKey: err?.error ?? "unknown"])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func listBooks() async throws -> [Book] { try await request("GET", "/books") }

    func getBookChunks(bookID: String) async throws -> [Chunk] {
        try await request("GET", "/books/\(bookID)/chunks")
    }

    func postEvent(device: String, seq: Int, type: String, payload: [String: String]) async throws
        -> SyncEvent
    {
        let body = try JSONEncoder().encode(
            EventRequest(device: device, seq: seq, type: type, payload: payload))
        return try await request("POST", "/events", body: body)
    }

    func importBook(title: String, author: String, fileURL: URL) async throws -> Book {
        let url = baseURL.appendingPathComponent("/books/import")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var bodyData = Data()
        func append(_ str: String) { bodyData.append(str.data(using: .utf8)!) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"title\"\r\n\r\n\(title)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"author\"\r\n\r\n\(author)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"book.epub\"\r\n")
        append("Content-Type: application/epub+zip\r\n\r\n")
        bodyData.append(try Data(contentsOf: fileURL))
        append("\r\n--\(boundary)--\r\n")
        req.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let err = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw URLError(
                .init(rawValue: (response as? HTTPURLResponse)?.statusCode ?? 0),
                userInfo: [NSLocalizedDescriptionKey: err?.error ?? "import failed"])
        }
        return try JSONDecoder().decode(Book.self, from: data)
    }

    func health() async throws -> [String: String] { try await request("GET", "/health") }
}

// MARK: - Local SQLite → models what each device stores

class LocalDB {
    let db: OpaquePointer

    init(path: String) throws {
        var handle: OpaquePointer?
        let rc = sqlite3_open(path, &handle)
        guard rc == SQLITE_OK, let handle else {
            throw NSError(domain: "SQLite", code: Int(rc), userInfo: nil)
        }
        db = handle
        try exec("PRAGMA journal_mode=WAL")
        try createSchema()
    }

    deinit { sqlite3_close(db) }

    // -- schema mirrors the design doc's device-side tables

    private func createSchema() throws {
        try exec(
            """
                CREATE TABLE IF NOT EXISTS book_chunks (
                    book_id TEXT NOT NULL,
                    chunk_index INTEGER NOT NULL,
                    title TEXT NOT NULL,
                    content TEXT NOT NULL,
                    PRIMARY KEY (book_id, chunk_index)
                )
            """)
        try exec(
            """
                CREATE TABLE IF NOT EXISTS highlights (
                    id TEXT PRIMARY KEY,
                    book_id TEXT NOT NULL,
                    start_pos INTEGER NOT NULL,
                    end_pos INTEGER NOT NULL,
                    text TEXT NOT NULL,
                    note TEXT NOT NULL DEFAULT '',
                    device TEXT NOT NULL,
                    created_at TEXT NOT NULL
                )
            """)
        try exec(
            """
                CREATE TABLE IF NOT EXISTS reading_state (
                    book_id TEXT NOT NULL,
                    device TEXT NOT NULL,
                    chunk_index INTEGER NOT NULL DEFAULT 0,
                    offset_val INTEGER NOT NULL DEFAULT 0,
                    updated_at TEXT NOT NULL,
                    PRIMARY KEY (book_id, device)
                )
            """)
        try exec(
            """
                CREATE TABLE IF NOT EXISTS vector_clock (
                    device TEXT PRIMARY KEY,
                    seq INTEGER NOT NULL DEFAULT 0
                )
            """)
    }

    // -- exec a single SQL statement

    func exec(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let msg = errMsg.flatMap { String(cString: $0) } ?? "unknown"
            sqlite3_free(errMsg)
            throw NSError(
                domain: "SQLite", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    // -- cache book chunks from the server
    func cacheChunks(bookID: String, chunks: [Chunk]) throws {
        try exec("DELETE FROM book_chunks WHERE book_id='\(bookID)'")
        for c in chunks {
            // Use parameterized binding to avoid SQL injection
            let sql =
                "INSERT INTO book_chunks (book_id, chunk_index, title, content) VALUES (?, ?, ?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
                continue
            }
            sqlite3_bind_text(stmt, 1, (bookID as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 2, Int32(c.index))
            sqlite3_bind_text(stmt, 3, (c.title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (c.content as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }

    // -- apply a highlight_added event to local SQLite

    func applyHighlight(event: SyncEvent) throws {
        guard let payload = event.payload,
            let bookID = payload["book_id"],
            let startStr = payload["start"],
            let endStr = payload["end"],
            let text = payload["text"],
            let start = Int(startStr),
            let end = Int(endStr)
        else { return }

        let highlightID = "\(event.device)-\(event.seq)"
        let sql = """
                INSERT OR REPLACE INTO highlights (id, book_id, start_pos, end_pos, text, note, device, created_at)
                VALUES (?, ?, ?, ?, ?, '', ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return }
        sqlite3_bind_text(stmt, 1, (highlightID as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (bookID as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 3, Int32(start))
        sqlite3_bind_int(stmt, 4, Int32(end))
        sqlite3_bind_text(stmt, 5, (text as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 6, (event.device as NSString).utf8String, -1, nil)
        let now = ISO8601DateFormatter().string(from: Date())
        sqlite3_bind_text(stmt, 7, (now as NSString).utf8String, -1, nil)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)

        // Advance vector clock for this device
        try updateVectorClock(device: event.device, seq: event.seq)
    }

    // -- apply a reading_position event

    func applyReadingPosition(event: SyncEvent) throws {
        guard let payload = event.payload,
            let bookID = payload["book_id"],
            let chunkStr = payload["chunk_index"],
            let offsetStr = payload["offset"],
            let chunk = Int(chunkStr),
            let offset = Int(offsetStr)
        else { return }

        let sql = """
                INSERT OR REPLACE INTO reading_state (book_id, device, chunk_index, offset_val, updated_at)
                VALUES (?, ?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        sqlite3_bind_text(stmt, 1, (bookID as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (event.device as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 3, Int32(chunk))
        sqlite3_bind_int(stmt, 4, Int32(offset))
        sqlite3_bind_text(stmt, 5, (now as NSString).utf8String, -1, nil)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)

        try updateVectorClock(device: event.device, seq: event.seq)
    }

    // -- vector clock

    func getVectorClock() -> [String: Int] {
        var clock: [String: Int] = [:]
        var stmt: OpaquePointer?
        guard
            sqlite3_prepare_v2(db, "SELECT device, seq FROM vector_clock", -1, &stmt, nil)
                == SQLITE_OK,
            let stmt
        else { return clock }
        while sqlite3_step(stmt) == SQLITE_ROW {
            let device = String(cString: sqlite3_column_text(stmt, 0))
            let seq = Int(sqlite3_column_int(stmt, 1))
            clock[device] = seq
        }
        sqlite3_finalize(stmt)
        return clock
    }

    func updateVectorClock(device: String, seq: Int) throws {
        try exec(
            """
                INSERT INTO vector_clock (device, seq) VALUES ('\(device)', \(seq))
                ON CONFLICT(device) DO UPDATE SET seq = max(seq, \(seq))
            """)
    }

    // -- query helpers

    func highlightCount() -> Int {
        var stmt: OpaquePointer?
        guard
            sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM highlights", -1, &stmt, nil) == SQLITE_OK,
            let stmt
        else { return 0 }
        let count = sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
        sqlite3_finalize(stmt)
        return count
    }

    func chunkCount(bookID: String) -> Int {
        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*) FROM book_chunks WHERE book_id=?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return 0 }
        sqlite3_bind_text(stmt, 1, (bookID as NSString).utf8String, -1, nil)
        let count = sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
        sqlite3_finalize(stmt)
        return count
    }

    func dumpHighlights() {
        var stmt: OpaquePointer?
        guard
            sqlite3_prepare_v2(
                db, "SELECT id, book_id, text, device FROM highlights", -1, &stmt, nil)
                == SQLITE_OK,
            let stmt
        else { return }
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let book = String(cString: sqlite3_column_text(stmt, 1))
            let text = String(cString: sqlite3_column_text(stmt, 2))
            let device = String(cString: sqlite3_column_text(stmt, 3))
            print("    ▸ [\(id)] \"\(text.prefix(40))…\" — book=\(book.prefix(8))… dev=\(device)")
        }
        sqlite3_finalize(stmt)
    }

    func dumpChunks(bookID: String) {
        var stmt: OpaquePointer?
        let sql =
            "SELECT chunk_index, title FROM book_chunks WHERE book_id=? ORDER BY chunk_index LIMIT 5"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return }
        sqlite3_bind_text(stmt, 1, (bookID as NSString).utf8String, -1, nil)
        while sqlite3_step(stmt) == SQLITE_ROW {
            let idx = sqlite3_column_int(stmt, 0)
            let title = String(cString: sqlite3_column_text(stmt, 1))
            print("    ▸ [\(idx)] \(title)")
        }
        sqlite3_finalize(stmt)
    }
}

// MARK: - Test

func runTests() async {
    let client = MoringaClient(baseURL: "http://localhost:8080", token: "devtoken")
    let dbDir = URL(fileURLWithPath: #file).deletingLastPathComponent().path
    let dbPath = "\(dbDir)/local.db"
    try? FileManager.default.removeItem(atPath: dbPath)
    guard let local = try? LocalDB(path: dbPath) else {
        print("❌ failed to open local db")
        return
    }
    print("Local DB: \(dbPath)\n")

    do {
        print("— GET /health")
        let h = try await client.health()
        print(" \(h["status"] ?? "?")\n")

        print("— GET /books")
        let books = try await client.listBooks()
        print("  \(books.count) book(s):")
        for b in books {
            print("    \(b.id.prefix(8))…  \(b.title) by \(b.author)")
        }

        guard let first = books.first else {
            print("  no books, import one first")
            return
        }
        let idPrefix = first.id.prefix(8)
        print("\n— GET /books/\(idPrefix)/chunks → local cache")
        let chunks = try await client.getBookChunks(bookID: first.id)
        try local.cacheChunks(bookID: first.id, chunks: chunks)
        print("  ✓ \(chunks.count) chunks cached locally")
        local.dumpChunks(bookID: first.id)

        print("\n— POST /events (highlight_added)")
        let event = try await client.postEvent(
            device: "swift-test",
            seq: 2,
            type: "highlight_added",
            payload: [
                "book_id": first.id,
                "start": "400",
                "end": "500",
                "text": "It is a truth universally acknowledged",
            ]
        )
        print("  event #\(event.id ?? 0) stored on server")

        print("\n— applying event to local SQLite")
        try local.applyHighlight(event: event)
        print("  \(local.highlightCount()) highlight(s) in local db")
        local.dumpHighlights()

        print("\n— POST /events (reading_position)")
        let posEvent = try await client.postEvent(
            device: "swift-test",
            seq: 3,
            type: "reading_position",
            payload: [
                "book_id": first.id,
                "chunk_index": "2",
                "offset": "150",
            ]
        )
        print(" event #\(posEvent.id ?? 0) stored")
        try local.applyReadingPosition(event: posEvent)

        print("\n— local vector clock")
        let clock = local.getVectorClock()
        for (dev, seq) in clock.sorted(by: { $0.key < $1.key }) {
            print("  ▸ \(dev): seq=\(seq)")
        }

        print("\n All tests passed")

    } catch {
        print("\n Error: \(error.localizedDescription)")
    }
}

print("Moringa API Client — Local-First Sync Test\n")
let sema = DispatchSemaphore(value: 0)
Task {
    await runTests()
    sema.signal()
}
sema.wait()
