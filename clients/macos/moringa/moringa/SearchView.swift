import SwiftUI

struct SearchView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    @State private var query = ""

    var results: (books: [Book], highlights: [Highlight], notes: [Note], drafts: [Draft]) {
        store.search(query)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 17)).foregroundColor(theme.ink3)
                    TextField("Search books, highlights, notes, drafts", text: $query)
                        .font(.system(size: 18)).foregroundColor(theme.ink).textFieldStyle(.plain)
                    Spacer()
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(theme.ink3)
                        }.buttonStyle(.plain)
                    }
                    Text("SQLite · local")
                        .font(.system(size: 11)).foregroundColor(theme.ink3)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(theme.surface2).clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.line2, lineWidth: 1))
                }
                .padding(.horizontal, 18).frame(height: 52)
                .background(theme.surface).clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(theme.line2, lineWidth: 1))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)

                if query.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(store.highlights.count) highlights")
                            Text("\(store.notes.count) notes")
                            Text("\(store.drafts.count) drafts")
                            Text("\(store.books.count) books")
                        }
                        .font(.system(size: 13)).foregroundColor(theme.ink3)
                        Spacer()
                    }
                    .padding(.top, 26)
                } else {
                    let r = results
                    if !r.highlights.isEmpty {
                        srGroup("Highlights", count: r.highlights.count) {
                            ForEach(r.highlights) { h in
                                srRow(icon: "highlighter",
                                      title: store.book(id: h.bookId)?.title ?? "Unknown book",
                                      snippet: marked(h.text, query))
                            }
                        }
                    }
                    if !r.notes.isEmpty {
                        srGroup("Notes", count: r.notes.count) {
                            ForEach(r.notes) { n in
                                srRow(icon: "note.text", title: n.title, snippet: marked(n.body.prefix200, query))
                            }
                        }
                    }
                    if !r.books.isEmpty {
                        srGroup("Books", count: r.books.count) {
                            ForEach(r.books) { b in
                                srRow(icon: "books.vertical", title: b.title,
                                      snippet: Text(b.author).foregroundColor(theme.ink2))
                            }
                        }
                    }
                    if !r.drafts.isEmpty {
                        srGroup("Drafts", count: r.drafts.count) {
                            ForEach(r.drafts) { d in
                                srRow(icon: "pencil.line", title: d.title, snippet: marked(d.excerpt, query))
                            }
                        }
                    }
                    if r.highlights.isEmpty && r.notes.isEmpty && r.books.isEmpty && r.drafts.isEmpty {
                        Text("No results for \"\(query)\"")
                            .font(.system(size: 14)).foregroundColor(theme.ink3)
                            .frame(maxWidth: .infinity, alignment: .center).padding(.top, 40)
                    }
                }
            }
            .padding(26).frame(maxWidth: 740).frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func srGroup<C: View>(_ label: String, count: Int, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(label.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.06).foregroundColor(theme.ink3)
                Text("\(count)").font(.system(size: 11, weight: .bold)).foregroundColor(theme.accentInk)
            }.padding(.top, 26).padding(.bottom, 10)
            content()
        }
    }

    @ViewBuilder
    private func srRow<S: View>(icon: String, title: String, snippet: S) -> some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(theme.accentSoft)
                Image(systemName: icon).font(.system(size: 15)).foregroundColor(theme.accentInk)
            }.frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14.5, weight: .semibold)).foregroundColor(theme.ink)
                snippet.font(.system(size: 13)).lineSpacing(2).lineLimit(2)
            }
            Spacer()
        }
        .padding(13).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func marked(_ text: String, _ query: String) -> Text {
        let q = query.lowercased()
        guard !q.isEmpty, let range = text.lowercased().range(of: q) else {
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

private extension String {
    var prefix200: String { String(prefix(200)) }
}
