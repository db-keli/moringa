import SwiftUI

// MARK: - Book

struct Book: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let format: String   // "epub" or "pdf"
    let colorHex: String
    var progress: Double
    var createdAt: String

    var color: Color { Color(hex: colorHex) }
    var isPDF: Bool { format == "pdf" }

    static func from(_ row: [String: Any?]) -> Book {
        Book(
            id:        row["id"]         as? String ?? UUID().uuidString,
            title:     row["title"]      as? String ?? "",
            author:    row["author"]     as? String ?? "",
            format:    row["format"]     as? String ?? "epub",
            colorHex:  row["color_hex"]  as? String ?? colorForId(row["id"] as? String ?? ""),
            progress:  row["progress"]   as? Double ?? 0,
            createdAt: row["created_at"] as? String ?? ""
        )
    }
}

// Generate a deterministic cover color from book ID
func colorForId(_ id: String) -> String {
    let palette = ["2F5D50","7C4A30","3A4A6B","9C7A2E","55402F","2B4D63","3C3C40","4A5A36","3E5648","4C4068"]
    let hash = id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
    return palette[abs(hash) % palette.count]
}

// MARK: - BookChunk

struct BookChunk: Identifiable {
    let bookId: String
    let index: Int
    let title: String
    let html: String   // offline fallback body HTML
    let path: String   // EPUB-internal path for URL loading, e.g. OEBPS/Text/ch01.xhtml

    var id: String { "\(bookId)-\(index)" }

    static func from(_ row: [String: Any?]) -> BookChunk {
        BookChunk(
            bookId: row["book_id"]     as? String ?? "",
            index:  (row["chunk_index"] as? Int64).map { Int($0) } ?? 0,
            title:  row["title"]       as? String ?? "",
            html:   row["html"]        as? String ?? "",
            path:   row["path"]        as? String ?? ""
        )
    }
}

// MARK: - ReadingState

struct ReadingState {
    let bookId: String
    var chunkIndex: Int
    var scrollPct: Double

    static func from(_ row: [String: Any?]) -> ReadingState {
        ReadingState(
            bookId:     row["book_id"]     as? String ?? "",
            chunkIndex: (row["chunk_index"] as? Int64).map { Int($0) } ?? 0,
            scrollPct:  row["scroll_pct"]  as? Double ?? 0
        )
    }
}

// MARK: - HLColor

enum HLColor: String, CaseIterable, Codable {
    case yellow, green, blue, pink
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .yellow: return M.hlYellow
        case .green:  return M.hlGreen
        case .blue:   return M.hlBlue
        case .pink:   return M.hlPink
        }
    }
    var textColor: Color {
        switch self {
        case .yellow: return Color(hex: "3a3320")
        case .green:  return Color(hex: "1f3424")
        case .blue:   return Color(hex: "1d3147")
        case .pink:   return Color(hex: "46202d")
        }
    }
}

// MARK: - Highlight

struct Highlight: Identifiable {
    let id: String
    let bookId: String
    let color: HLColor
    let text: String
    let loc: String
    var note: String?
    let createdAt: String

    static func from(_ row: [String: Any?]) -> Highlight {
        Highlight(
            id:        row["id"]         as? String ?? UUID().uuidString,
            bookId:    row["book_id"]    as? String ?? "",
            color:     HLColor(rawValue: row["color"] as? String ?? "yellow") ?? .yellow,
            text:      row["text"]       as? String ?? "",
            loc:       row["loc"]        as? String ?? "",
            note:      row["note"]       as? String,
            createdAt: row["created_at"] as? String ?? ""
        )
    }
}

// MARK: - Note

struct Note: Identifiable {
    let id: String
    var title: String
    var body: String
    let bookId: String?
    let createdAt: String

    static func from(_ row: [String: Any?]) -> Note {
        Note(
            id:        row["id"]         as? String ?? UUID().uuidString,
            title:     row["title"]      as? String ?? "",
            body:      row["body"]       as? String ?? "",
            bookId:    row["book_id"]    as? String,
            createdAt: row["created_at"] as? String ?? ""
        )
    }
}

// MARK: - Draft

struct DraftPara {
    let isHeading: Bool
    let text: String
}

enum DraftStatus: String, Codable { case draft, published }

struct Draft: Identifiable {
    let id: String
    var title: String
    var body: String
    var status: DraftStatus
    let createdAt: String
    var updatedAt: String

    var wordCount: Int { body.split(separator: " ").count }
    var excerpt: String { String(body.prefix(200)) }

    var paragraphs: [DraftPara] {
        body.components(separatedBy: "\n").compactMap { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { return nil }
            if t.hasPrefix("## ") { return DraftPara(isHeading: true, text: String(t.dropFirst(3))) }
            return DraftPara(isHeading: false, text: t)
        }
    }

    static func from(_ row: [String: Any?]) -> Draft {
        Draft(
            id:        row["id"]         as? String ?? UUID().uuidString,
            title:     row["title"]      as? String ?? "",
            body:      row["body"]       as? String ?? "",
            status:    DraftStatus(rawValue: row["status"] as? String ?? "draft") ?? .draft,
            createdAt: row["created_at"] as? String ?? "",
            updatedAt: row["updated_at"] as? String ?? ""
        )
    }
}

// MARK: - Sync / Settings

struct SyncInfo {
    var isConnected: Bool = false
    var lastSynced: String = "never"
    var queue: Int = 0
    var serverURL: String = ""
    var deviceName: String = {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return UIDevice.current.name
        #endif
    }()
}
