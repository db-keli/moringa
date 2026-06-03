import SwiftUI

struct SearchView: View {
    @Environment(AppTheme.self) var theme
    @State private var query: String = "deliberately"

    var ql: String { query.trimmingCharacters(in: .whitespaces).lowercased() }

    var hlResults:   [Highlight] { ql.isEmpty ? [] : MockData.highlights.filter { $0.text.lowercased().contains(ql) } }
    var noteResults: [Note]      { ql.isEmpty ? [] : MockData.notes.filter { ($0.title + $0.body).lowercased().contains(ql) } }
    var bookResults: [Book]      { ql.isEmpty ? [] : MockData.books.filter { ($0.title + $0.author).lowercased().contains(ql) } }
    var draftResults:[Draft]     { ql.isEmpty ? [] : MockData.drafts.filter { ($0.title + $0.excerpt).lowercased().contains(ql) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Big search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17)).foregroundColor(theme.ink3)
                    TextField("Search books, highlights, notes, drafts", text: $query)
                        .font(.system(size: 18)).foregroundColor(theme.ink).textFieldStyle(.plain)
                    Spacer()
                    Text("FTS5 · local")
                        .font(.system(size: 11)).foregroundColor(theme.ink3)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(theme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.line2, lineWidth: 1))
                }
                .padding(.horizontal, 18).frame(height: 52)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(theme.line2, lineWidth: 1))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)

                if !hlResults.isEmpty {
                    searchGroup(label: "Highlights", count: hlResults.count) {
                        ForEach(hlResults) { h in
                            searchResult(icon: "highlighter",
                                         title: MockData.book(id: h.bookId)?.title ?? "",
                                         snippet: highlight(h.text, query: ql))
                        }
                    }
                }
                if !noteResults.isEmpty {
                    searchGroup(label: "Notes", count: noteResults.count) {
                        ForEach(noteResults) { n in
                            searchResult(icon: "note.text",
                                         title: n.title,
                                         snippet: highlight(String(n.body.prefix(120)), query: ql))
                        }
                    }
                }
                if !bookResults.isEmpty {
                    searchGroup(label: "Books", count: bookResults.count) {
                        ForEach(bookResults) { b in
                            searchResult(icon: "books.vertical", title: b.title, snippet: Text(b.author).foregroundColor(theme.ink2))
                        }
                    }
                }
                if !draftResults.isEmpty {
                    searchGroup(label: "Drafts", count: draftResults.count) {
                        ForEach(draftResults) { d in
                            searchResult(icon: "pencil.line",
                                         title: d.title,
                                         snippet: highlight(d.excerpt, query: ql))
                        }
                    }
                }
                if !ql.isEmpty && hlResults.isEmpty && noteResults.isEmpty && bookResults.isEmpty && draftResults.isEmpty {
                    Text("No matches on this device. Press Return to search the server.")
                        .font(.system(size: 14)).foregroundColor(theme.ink3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .padding(26)
            .frame(maxWidth: 740)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func searchGroup<Content: View>(label: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(label.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.06).foregroundColor(theme.ink3)
                Text("\(count)").font(.system(size: 11, weight: .bold)).foregroundColor(theme.accentInk)
            }
            .padding(.top, 26).padding(.bottom, 10)
            content()
        }
    }

    @ViewBuilder
    private func searchResult<Snippet: View>(icon: String, title: String, snippet: Snippet) -> some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(theme.accentSoft)
                Image(systemName: icon).font(.system(size: 15)).foregroundColor(theme.accentInk)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14.5, weight: .semibold)).foregroundColor(theme.ink)
                snippet.font(.system(size: 13)).lineSpacing(2).lineLimit(2)
            }
            Spacer()
        }
        .padding(13)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onHover { _ in }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func highlight(_ text: String, query: String) -> Text {
        guard !query.isEmpty,
              let range = text.lowercased().range(of: query) else {
            return Text(text).foregroundColor(theme.ink2)
        }
        let before = String(text[text.startIndex..<range.lowerBound])
        let match  = String(text[range])
        let after  = String(text[range.upperBound...])
        return Text(before).foregroundColor(theme.ink2)
             + Text(match).foregroundColor(theme.ink).bold()
             + Text(after).foregroundColor(theme.ink2)
    }
}
