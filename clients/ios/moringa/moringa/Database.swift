import SQLite3
import Foundation

// MARK: - Errors

enum DBError: Error, LocalizedError {
    case open(String)
    case prepare(String)
    case step(String)

    var errorDescription: String? {
        switch self {
        case .open(let m):    return "DB open: \(m)"
        case .prepare(let m): return "DB prepare: \(m)"
        case .step(let m):    return "DB step: \(m)"
        }
    }
}

// MARK: - Database

final class Database {
    private var db: OpaquePointer?

    // MARK: Init

    init() throws {
        let dir: URL
        #if os(macOS)
        dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("moringa")
        #else
        dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        #endif
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("moringa.db").path

        guard sqlite3_open_v2(path, &db,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK
        else { throw DBError.open(dbError) }

        try exec("PRAGMA journal_mode=WAL")
        try exec("PRAGMA foreign_keys=ON")
        try migrate()
    }

    deinit { sqlite3_close(db) }

    private var dbError: String { String(cString: sqlite3_errmsg(db)) }

    // MARK: - Migrations

    private func migrate() throws {
        try exec("""
            CREATE TABLE IF NOT EXISTS db_version (v INTEGER NOT NULL);
        """)

        let v = (try? scalar("SELECT v FROM db_version LIMIT 1") as? Int64).flatMap { Int($0) } ?? 0

        if v < 1 {
            try exec("""
                CREATE TABLE IF NOT EXISTS books (
                    id          TEXT PRIMARY KEY,
                    title       TEXT NOT NULL,
                    author      TEXT NOT NULL DEFAULT '',
                    color_hex   TEXT NOT NULL DEFAULT '2F5D50',
                    progress    REAL NOT NULL DEFAULT 0,
                    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
                );

                CREATE TABLE IF NOT EXISTS book_chunks (
                    book_id     TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    chunk_index INTEGER NOT NULL,
                    title       TEXT NOT NULL DEFAULT '',
                    html        TEXT NOT NULL DEFAULT '',
                    PRIMARY KEY (book_id, chunk_index)
                );

                CREATE TABLE IF NOT EXISTS reading_state (
                    book_id      TEXT PRIMARY KEY REFERENCES books(id) ON DELETE CASCADE,
                    chunk_index  INTEGER NOT NULL DEFAULT 0,
                    scroll_pct   REAL NOT NULL DEFAULT 0,
                    updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
                );

                CREATE TABLE IF NOT EXISTS highlights (
                    id          TEXT PRIMARY KEY,
                    book_id     TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                    color       TEXT NOT NULL DEFAULT 'yellow',
                    text        TEXT NOT NULL,
                    loc         TEXT NOT NULL DEFAULT '',
                    note        TEXT,
                    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
                );

                CREATE TABLE IF NOT EXISTS notes (
                    id          TEXT PRIMARY KEY,
                    title       TEXT NOT NULL DEFAULT '',
                    body        TEXT NOT NULL DEFAULT '',
                    book_id     TEXT REFERENCES books(id) ON DELETE SET NULL,
                    created_at  TEXT NOT NULL DEFAULT (datetime('now')),
                    updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
                );

                CREATE TABLE IF NOT EXISTS drafts (
                    id          TEXT PRIMARY KEY,
                    title       TEXT NOT NULL DEFAULT 'Untitled',
                    body        TEXT NOT NULL DEFAULT '',
                    status      TEXT NOT NULL DEFAULT 'draft',
                    created_at  TEXT NOT NULL DEFAULT (datetime('now')),
                    updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
                );

                CREATE TABLE IF NOT EXISTS sync_queue (
                    id       INTEGER PRIMARY KEY AUTOINCREMENT,
                    device   TEXT NOT NULL,
                    seq      INTEGER NOT NULL,
                    type     TEXT NOT NULL,
                    payload  TEXT NOT NULL DEFAULT '{}',
                    created_at TEXT NOT NULL DEFAULT (datetime('now'))
                );

                CREATE TABLE IF NOT EXISTS vector_clock (
                    device TEXT PRIMARY KEY,
                    seq    INTEGER NOT NULL DEFAULT 0
                );

                CREATE INDEX IF NOT EXISTS idx_hl_book    ON highlights(book_id);
                CREATE INDEX IF NOT EXISTS idx_notes_book ON notes(book_id);
            """)
            try exec("INSERT INTO db_version VALUES (1)")
        }

        if v < 2 {
            try exec("""
                CREATE TABLE IF NOT EXISTS received_clock (
                    device  TEXT PRIMARY KEY,
                    seq     INTEGER NOT NULL DEFAULT 0
                )
            """)
            try exec("UPDATE db_version SET v = 2")
        }

        if v < 3 {
            try exec("ALTER TABLE book_chunks ADD COLUMN path TEXT NOT NULL DEFAULT ''")
            try exec("UPDATE db_version SET v = 3")
        }

        if v < 4 {
            try exec("ALTER TABLE books ADD COLUMN format TEXT NOT NULL DEFAULT 'epub'")
            try exec("UPDATE db_version SET v = 4")
        }
    }

    // MARK: - Primitive exec / query

    func exec(_ sql: String) throws {
        // Split on ";" to handle multi-statement strings
        for stmt in sql.split(separator: ";", omittingEmptySubsequences: true)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter({ !$0.isEmpty }) {
            var err: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, stmt, nil, nil, &err) != SQLITE_OK {
                let msg = err.map { String(cString: $0) } ?? dbError
                sqlite3_free(err)
                throw DBError.step(msg)
            }
        }
    }

    func rows(_ sql: String, _ bindings: [Any?] = []) throws -> [[String: Any?]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(dbError)
        }
        defer { sqlite3_finalize(stmt) }

        for (i, val) in bindings.enumerated() {
            let idx = Int32(i + 1)
            switch val {
            case nil:              sqlite3_bind_null(stmt, idx)
            case let s as String:  sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
            case let n as Int:     sqlite3_bind_int64(stmt, idx, Int64(n))
            case let n as Int64:   sqlite3_bind_int64(stmt, idx, n)
            case let d as Double:  sqlite3_bind_double(stmt, idx, d)
            case let b as Bool:    sqlite3_bind_int64(stmt, idx, b ? 1 : 0)
            default:
                if let s = val.map({ "\($0)" }) {
                    sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
                }
            }
        }

        var result: [[String: Any?]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any?] = [:]
            for col in 0..<sqlite3_column_count(stmt) {
                let name = String(cString: sqlite3_column_name(stmt, col))
                switch sqlite3_column_type(stmt, col) {
                case SQLITE_INTEGER: row[name] = sqlite3_column_int64(stmt, col)
                case SQLITE_FLOAT:   row[name] = sqlite3_column_double(stmt, col)
                case SQLITE_TEXT:    row[name] = String(cString: sqlite3_column_text(stmt, col))
                case SQLITE_NULL:    row[name] = nil
                default:             row[name] = nil
                }
            }
            result.append(row)
        }
        return result
    }

    func scalar(_ sql: String, _ bindings: [Any?] = []) throws -> Any? {
        return try rows(sql, bindings).first?.values.first ?? nil
    }

    func run(_ sql: String, _ bindings: [Any?] = []) throws {
        let _ = try rows(sql, bindings)
    }

    // MARK: - Books

    func insertBook(_ b: Book) throws {
        try run("""
            INSERT OR IGNORE INTO books (id, title, author, format, color_hex, progress, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, [b.id, b.title, b.author, b.format, b.colorHex, b.progress, b.createdAt])
    }

    func updateBookProgress(id: String, progress: Double) throws {
        try run("UPDATE books SET progress = ? WHERE id = ?", [progress, id])
    }

    func allBooks() throws -> [Book] {
        return try rows("SELECT * FROM books ORDER BY created_at DESC").map(Book.from)
    }

    func deleteBook(id: String) throws {
        try run("DELETE FROM books WHERE id = ?", [id])
    }

    // MARK: - Chunks

    func insertChunks(_ chunks: [BookChunk], bookId: String) throws {
        try run("DELETE FROM book_chunks WHERE book_id = ?", [bookId])
        for c in chunks {
            try run("""
                INSERT INTO book_chunks (book_id, chunk_index, title, html, path)
                VALUES (?, ?, ?, ?, ?)
            """, [bookId, c.index, c.title, c.html, c.path])
        }
    }

    func chunks(for bookId: String) throws -> [BookChunk] {
        return try rows("SELECT * FROM book_chunks WHERE book_id = ? ORDER BY chunk_index", [bookId])
            .map(BookChunk.from)
    }

    func hasChunks(for bookId: String) throws -> Bool {
        let n = try scalar("SELECT COUNT(*) FROM book_chunks WHERE book_id = ?", [bookId]) as? Int64 ?? 0
        return n > 0
    }

    // MARK: - Reading state

    func readingState(for bookId: String) throws -> ReadingState? {
        return try rows("SELECT * FROM reading_state WHERE book_id = ?", [bookId]).first.map(ReadingState.from)
    }

    func saveReadingState(_ s: ReadingState) throws {
        try run("""
            INSERT INTO reading_state (book_id, chunk_index, scroll_pct, updated_at)
            VALUES (?, ?, ?, datetime('now'))
            ON CONFLICT(book_id) DO UPDATE SET
                chunk_index = excluded.chunk_index,
                scroll_pct  = excluded.scroll_pct,
                updated_at  = excluded.updated_at
        """, [s.bookId, s.chunkIndex, s.scrollPct])
        try updateBookProgress(id: s.bookId, progress: s.scrollPct)
    }

    // MARK: - Highlights

    // Insert only if not already present — used by SSE consumer so local notes survive.
    func insertHighlightIfAbsent(_ h: Highlight) throws {
        try run("""
            INSERT OR IGNORE INTO highlights (id, book_id, color, text, loc, note, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, [h.id, h.bookId, h.color.rawValue, h.text, h.loc, h.note, h.createdAt])
    }

    func insertHighlight(_ h: Highlight) throws {
        try run("""
            INSERT OR REPLACE INTO highlights (id, book_id, color, text, loc, note, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, [h.id, h.bookId, h.color.rawValue, h.text, h.loc, h.note, h.createdAt])
    }

    func updateHighlightNote(id: String, note: String?) throws {
        try run("UPDATE highlights SET note = ? WHERE id = ?", [note, id])
    }

    func deleteHighlight(id: String) throws {
        try run("DELETE FROM highlights WHERE id = ?", [id])
    }

    func allHighlights() throws -> [Highlight] {
        return try rows("SELECT * FROM highlights ORDER BY created_at DESC").map(Highlight.from)
    }

    func highlights(for bookId: String) throws -> [Highlight] {
        return try rows("SELECT * FROM highlights WHERE book_id = ? ORDER BY created_at", [bookId])
            .map(Highlight.from)
    }

    // MARK: - Notes

    func insertNoteIfAbsent(_ n: Note) throws {
        try run("""
            INSERT OR IGNORE INTO notes (id, title, body, book_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, datetime('now'))
        """, [n.id, n.title, n.body, n.bookId, n.createdAt])
    }

    func insertNote(_ n: Note) throws {
        try run("""
            INSERT OR REPLACE INTO notes (id, title, body, book_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, datetime('now'))
        """, [n.id, n.title, n.body, n.bookId, n.createdAt])
    }

    func updateNote(id: String, title: String, body: String) throws {
        try run("""
            UPDATE notes SET title = ?, body = ?, updated_at = datetime('now') WHERE id = ?
        """, [title, body, id])
    }

    func deleteNote(id: String) throws {
        try run("DELETE FROM notes WHERE id = ?", [id])
    }

    func allNotes() throws -> [Note] {
        return try rows("SELECT * FROM notes ORDER BY updated_at DESC").map(Note.from)
    }

    // MARK: - Drafts

    func insertDraftIfAbsent(_ d: Draft) throws {
        try run("""
            INSERT OR IGNORE INTO drafts (id, title, body, status, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, datetime('now'))
        """, [d.id, d.title, d.body, d.status.rawValue, d.createdAt])
    }

    func insertDraft(_ d: Draft) throws {
        try run("""
            INSERT OR REPLACE INTO drafts (id, title, body, status, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, datetime('now'))
        """, [d.id, d.title, d.body, d.status.rawValue, d.createdAt])
    }

    func updateDraft(id: String, title: String, body: String) throws {
        try run("""
            UPDATE drafts SET title = ?, body = ?, updated_at = datetime('now') WHERE id = ?
        """, [title, body, id])
    }

    func deleteDraft(id: String) throws {
        try run("DELETE FROM drafts WHERE id = ?", [id])
    }

    func allDrafts() throws -> [Draft] {
        return try rows("SELECT * FROM drafts ORDER BY created_at DESC").map(Draft.from)
    }

    // MARK: - Sync queue

    func nextSeq(device: String) throws -> Int {
        let cur = (try? scalar("SELECT seq FROM vector_clock WHERE device = ?", [device]) as? Int64)
            .flatMap { Int($0) } ?? 0
        let next = cur + 1
        try run("""
            INSERT INTO vector_clock (device, seq) VALUES (?, ?)
            ON CONFLICT(device) DO UPDATE SET seq = excluded.seq
        """, [device, next])
        return next
    }

    func enqueueEvent(device: String, type: String, payload: String) throws {
        let seq = try nextSeq(device: device)
        try run("""
            INSERT INTO sync_queue (device, seq, type, payload) VALUES (?, ?, ?, ?)
        """, [device, seq, type, payload])
    }

    func pendingEvents() throws -> [(id: Int, device: String, seq: Int, type: String, payload: String)] {
        return try rows("SELECT * FROM sync_queue ORDER BY id")
            .compactMap { row in
                guard
                    let id      = row["id"] as? Int64,
                    let device  = row["device"] as? String,
                    let seq     = row["seq"] as? Int64,
                    let type    = row["type"] as? String,
                    let payload = row["payload"] as? String
                else { return nil }
                return (Int(id), device, Int(seq), type, payload)
            }
    }

    func deleteQueuedEvent(id: Int) throws {
        try run("DELETE FROM sync_queue WHERE id = ?", [id])
    }

    func vectorClock() throws -> [String: Int] {
        var clock: [String: Int] = [:]
        for row in (try? rows("SELECT device, seq FROM vector_clock")) ?? [] {
            if let d = row["device"] as? String, let s = row["seq"] as? Int64 {
                clock[d] = Int(s)
            }
        }
        return clock
    }

    // MARK: - Received clock (tracks highest seq seen from each remote device)

    func receivedClock() throws -> [String: Int] {
        var clock: [String: Int] = [:]
        for row in (try rows("SELECT device, seq FROM received_clock")) {
            if let d = row["device"] as? String, let s = row["seq"] as? Int64 {
                clock[d] = Int(s)
            }
        }
        return clock
    }

    func updateReceivedClock(device: String, seq: Int) throws {
        try run("""
            INSERT INTO received_clock (device, seq) VALUES (?, ?)
            ON CONFLICT(device) DO UPDATE SET seq = MAX(excluded.seq, received_clock.seq)
        """, [device, seq])
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
