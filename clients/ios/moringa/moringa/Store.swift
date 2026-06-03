import Foundation
import SwiftUI

// MARK: - Device ID

private func deviceID() -> String {
    let key = "moringa.deviceID"
    if let d = UserDefaults.standard.string(forKey: key) { return d }
    let d = "mac-\(UUID().uuidString.prefix(8))"
    UserDefaults.standard.set(d, forKey: key)
    return d
}

// MARK: - Store

@Observable
final class Store {
    // Published state
    var books:      [Book]      = []
    var highlights: [Highlight] = []
    var notes:      [Note]      = []
    var drafts:     [Draft]     = []
    var syncInfo    = SyncInfo()
    var error:      String?

    // Config (persisted)
    var serverURL: String = UserDefaults.standard.string(forKey: "moringa.serverURL") ?? "" {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: "moringa.serverURL")
            api.configure(baseURL: serverURL, token: authToken)
            syncInfo.serverURL = serverURL
        }
    }
    var authToken: String = UserDefaults.standard.string(forKey: "moringa.authToken") ?? "" {
        didSet {
            UserDefaults.standard.set(authToken, forKey: "moringa.authToken")
            api.configure(baseURL: serverURL, token: authToken)
        }
    }

    let db: Database
    let api: APIClient
    let deviceId = deviceID()

    init() {
        let db = (try? Database()) ?? { fatalError("Cannot open database") }()
        self.db   = db
        self.api  = APIClient(
            baseURL: UserDefaults.standard.string(forKey: "moringa.serverURL") ?? "",
            token:   UserDefaults.standard.string(forKey: "moringa.authToken") ?? ""
        )
        syncInfo.serverURL = serverURL
        loadLocal()
    }

    // MARK: - Load from SQLite

    func loadLocal() {
        books      = (try? db.allBooks())      ?? []
        highlights = (try? db.allHighlights()) ?? []
        notes      = (try? db.allNotes())      ?? []
        drafts     = (try? db.allDrafts())     ?? []
        syncInfo.queue = (try? db.pendingEvents().count) ?? 0
    }

    // MARK: - Server sync

    func syncWithServer() async {
        guard api.isConfigured else { return }
        do {
            // Fetch books list
            let apiBooks = try await api.fetchBooks()
            for ab in apiBooks {
                let colorHex = colorForId(ab.id)
                let b = Book(id: ab.id, title: ab.title, author: ab.author,
                             colorHex: colorHex, progress: 0, createdAt: ab.created_at)
                try db.insertBook(b)
            }
            await MainActor.run {
                books = (try? db.allBooks()) ?? []
                syncInfo.isConnected = true
                syncInfo.lastSynced = "just now"
            }
            // Drain sync queue
            await drainQueue()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                syncInfo.isConnected = false
            }
        }
    }

    // MARK: - EPUB Import

    func importBook(title: String, author: String, fileURL: URL) async throws {
        let ab = try await api.importBook(title: title, author: author, fileURL: fileURL)
        let b = Book(id: ab.id, title: ab.title, author: ab.author,
                     colorHex: colorForId(ab.id), progress: 0, createdAt: ab.created_at)
        try db.insertBook(b)
        await MainActor.run { books = (try? db.allBooks()) ?? [] }
    }

    // MARK: - Chunks

    func chunks(for book: Book) async throws -> [BookChunk] {
        if (try? db.hasChunks(for: book.id)) == true {
            return (try? db.chunks(for: book.id)) ?? []
        }
        // Cold load from server
        let apiChunks = try await api.fetchChunks(bookId: book.id)
        let chunks = apiChunks.map { BookChunk(bookId: book.id, index: $0.index, title: $0.title, html: $0.html) }
        try db.insertChunks(chunks, bookId: book.id)
        return chunks
    }

    // MARK: - Reading state

    func readingState(for book: Book) -> ReadingState {
        (try? db.readingState(for: book.id)) ?? ReadingState(bookId: book.id, chunkIndex: 0, scrollPct: 0)
    }

    func savePosition(bookId: String, chunkIndex: Int, scrollPct: Double) {
        let s = ReadingState(bookId: bookId, chunkIndex: chunkIndex, scrollPct: scrollPct)
        try? db.saveReadingState(s)
        if let idx = books.firstIndex(where: { $0.id == bookId }) {
            books[idx].progress = scrollPct
        }
        enqueueEvent(type: "position_updated",
                     payload: ["book_id": bookId, "chunk_index": chunkIndex, "scroll_pct": scrollPct])
    }

    // MARK: - Highlights

    func addHighlight(bookId: String, color: HLColor, text: String, loc: String) {
        let h = Highlight(id: UUID().uuidString, bookId: bookId, color: color,
                          text: text, loc: loc, note: nil, createdAt: iso8601())
        try? db.insertHighlight(h)
        highlights = (try? db.allHighlights()) ?? []
        enqueueEvent(type: "highlight_added",
                     payload: ["id": h.id, "book_id": bookId, "color": color.rawValue, "text": text, "loc": loc])
    }

    func updateHighlightNote(id: String, note: String) {
        try? db.updateHighlightNote(id: id, note: note.isEmpty ? nil : note)
        highlights = (try? db.allHighlights()) ?? []
    }

    func deleteHighlight(id: String) {
        try? db.deleteHighlight(id: id)
        highlights = (try? db.allHighlights()) ?? []
        enqueueEvent(type: "highlight_removed", payload: ["id": id])
    }

    // MARK: - Notes

    func createNote(title: String, body: String, bookId: String? = nil) {
        let n = Note(id: UUID().uuidString, title: title, body: body,
                     bookId: bookId, createdAt: iso8601())
        try? db.insertNote(n)
        notes = (try? db.allNotes()) ?? []
        enqueueEvent(type: "note_created", payload: ["id": n.id, "title": title, "body": body])
    }

    func updateNote(id: String, title: String, body: String) {
        try? db.updateNote(id: id, title: title, body: body)
        notes = (try? db.allNotes()) ?? []
        enqueueEvent(type: "note_updated", payload: ["id": id, "title": title, "body": body])
    }

    func deleteNote(id: String) {
        try? db.deleteNote(id: id)
        notes = (try? db.allNotes()) ?? []
        enqueueEvent(type: "note_deleted", payload: ["id": id])
    }

    // MARK: - Drafts

    func createDraft(title: String = "Untitled") {
        let d = Draft(id: UUID().uuidString, title: title, body: "",
                      status: .draft, createdAt: iso8601(), updatedAt: iso8601())
        try? db.insertDraft(d)
        drafts = (try? db.allDrafts()) ?? []
    }

    func updateDraft(id: String, title: String, body: String) {
        try? db.updateDraft(id: id, title: title, body: body)
        drafts = (try? db.allDrafts()) ?? []
        enqueueEvent(type: "blog_updated", payload: ["id": id, "title": title, "body": body])
    }

    func deleteDraft(id: String) {
        try? db.deleteDraft(id: id)
        drafts = (try? db.allDrafts()) ?? []
    }

    func book(id: String) -> Book? { books.first(where: { $0.id == id }) }

    // MARK: - Sync queue

    private func enqueueEvent(type: String, payload: [String: Any]) {
        let json = (try? JSONSerialization.data(withJSONObject: payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        try? db.enqueueEvent(device: deviceId, type: type, payload: json)
        syncInfo.queue = (try? db.pendingEvents().count) ?? 0
    }

    func drainQueue() async {
        guard api.isConfigured else { return }
        let pending = (try? db.pendingEvents()) ?? []
        for event in pending {
            let payload = (try? JSONSerialization.jsonObject(with: event.payload.data(using: .utf8) ?? Data()) as? [String: Any]) ?? [:]
            do {
                try await api.postEvent(device: event.device, seq: event.seq, type: event.type, payload: payload)
                try? db.deleteQueuedEvent(id: event.id)
            } catch {
                break // stop on first failure, retry later
            }
        }
        await MainActor.run {
            syncInfo.queue = (try? db.pendingEvents().count) ?? 0
        }
    }

    // MARK: - Search

    func search(_ query: String) -> (books: [Book], highlights: [Highlight], notes: [Note], drafts: [Draft]) {
        let q = query.lowercased()
        guard !q.isEmpty else { return ([], [], [], []) }
        return (
            books:      books.filter { ($0.title + $0.author).lowercased().contains(q) },
            highlights: highlights.filter { $0.text.lowercased().contains(q) },
            notes:      notes.filter { ($0.title + $0.body).lowercased().contains(q) },
            drafts:     drafts.filter { ($0.title + $0.body).lowercased().contains(q) }
        )
    }
}

// MARK: - Helpers

private func iso8601() -> String {
    ISO8601DateFormatter().string(from: Date())
}
