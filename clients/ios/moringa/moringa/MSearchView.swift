import SwiftUI

struct MSearchView: View {
    @EnvironmentObject var theme: AppTheme
    var onBack: () -> Void
    @State private var query: String = ""

    var ql: String { query.trimmingCharacters(in: .whitespaces).lowercased() }

    var hlResults:   [Highlight] { ql.isEmpty ? MockData.highlights : MockData.highlights.filter { $0.text.lowercased().contains(ql) } }
    var noteResults: [Note]      { ql.isEmpty ? MockData.notes      : MockData.notes.filter { ($0.title + $0.body).lowercased().contains(ql) } }
    var bookResults: [Book]      { ql.isEmpty ? MockData.books      : MockData.books.filter { ($0.title + $0.author).lowercased().contains(ql) } }

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar + Done
                HStack(spacing: 10) {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15)).foregroundColor(theme.ink3)
                        TextField("Search everything", text: $query)
                            .font(.system(size: 15)).foregroundColor(theme.ink)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12).frame(height: 38)
                    .background(theme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .frame(maxWidth: .infinity)

                    Button("Done", action: onBack)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.accentInk)
                }
                .padding(.horizontal, 16)
                .padding(.top, 58).padding(.bottom, 10)
                .background(theme.paper)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !bookResults.isEmpty {
                            mSection("Books")
                            ForEach(bookResults) { b in
                                HStack(spacing: 12) {
                                    BookCoverView(book: b, small: true).frame(width: 30)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(b.title).font(.system(size: 15, weight: .semibold)).foregroundColor(theme.ink)
                                        Text(b.author).font(.system(size: 12.5)).foregroundColor(theme.ink3)
                                    }
                                }
                                .padding(.horizontal, 20).padding(.vertical, 10)
                            }
                        }

                        if !hlResults.isEmpty {
                            mSection("Highlights")
                            ForEach(hlResults) { h in
                                MHLCard(highlight: h)
                                    .padding(.horizontal, 20).padding(.bottom, 10)
                            }
                        }

                        if !noteResults.isEmpty {
                            mSection("Notes")
                            ForEach(noteResults) { n in
                                MNoteCard(note: n)
                                    .padding(.horizontal, 20).padding(.bottom, 10)
                            }
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    @ViewBuilder
    private func mSection(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold)).tracking(0.05)
            .foregroundColor(theme.ink3)
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 8)
    }
}
