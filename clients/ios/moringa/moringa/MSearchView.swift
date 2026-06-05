import SwiftUI

struct MSearchView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    var onBack: () -> Void
    @State private var query = ""

    var results: (books: [Book], highlights: [Highlight], notes: [Note], drafts: [Draft]) {
        store.search(query)
    }

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundColor(theme.ink3)
                        TextField("Search everything", text: $query)
                            .font(.system(size: 15)).foregroundColor(theme.ink).textFieldStyle(.plain)
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(theme.ink3)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12).frame(height: 38)
                    .background(theme.surface2).clipShape(RoundedRectangle(cornerRadius: 11)).frame(maxWidth: .infinity)
                    Button("Done", action: onBack)
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(theme.accentInk)
                }
                .padding(.horizontal, 16).padding(.top, 58).padding(.bottom, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        let r = results
                        if query.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(store.highlights.count) highlights")
                                Text("\(store.notes.count) notes")
                                Text("\(store.books.count) books")
                            }.font(.system(size: 13)).foregroundColor(theme.ink3)
                                .padding(.horizontal, 20).padding(.top, 16)
                        } else {
                            if !r.books.isEmpty {
                                mSection("Books")
                                ForEach(r.books) { b in
                                    HStack(spacing: 12) {
                                        BookCoverView(book: b, small: true).frame(width: 30)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(b.title).font(.system(size: 15, weight: .semibold)).foregroundColor(theme.ink)
                                            Text(b.author).font(.system(size: 12.5)).foregroundColor(theme.ink3)
                                        }
                                    }.padding(.horizontal, 20).padding(.vertical, 10)
                                }
                            }
                            if !r.highlights.isEmpty {
                                mSection("Highlights")
                                ForEach(r.highlights) { h in
                                    MHLCard(highlight: h, book: store.book(id: h.bookId))
                                        .padding(.horizontal, 20).padding(.bottom, 10)
                                }
                            }
                            if !r.notes.isEmpty {
                                mSection("Notes")
                                ForEach(r.notes) { n in
                                    MNoteCard(note: n).padding(.horizontal, 20).padding(.bottom, 10)
                                }
                            }
                            if r.books.isEmpty && r.highlights.isEmpty && r.notes.isEmpty {
                                Text("No results for \"\(query)\"")
                                    .font(.system(size: 14)).foregroundColor(theme.ink3)
                                    .frame(maxWidth: .infinity, alignment: .center).padding(.top, 40)
                            }
                        }
                        Spacer(minLength: 30)
                    }.padding(.top, 8)
                }
            }
        }
    }

    @ViewBuilder private func mSection(_ t: String) -> some View {
        Text(t.uppercased()).font(.system(size: 12, weight: .bold)).tracking(0.05).foregroundColor(theme.ink3)
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 8)
    }
}
