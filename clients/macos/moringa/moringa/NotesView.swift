import SwiftUI

struct NotesView: View {
    @Environment(AppTheme.self) var theme

    var body: some View {
        VStack(spacing: 0) {
            // Topbar
            HStack {
                Text("Notes").font(.system(size: 20, weight: .bold)).foregroundColor(theme.ink)
                Spacer()
                Button {
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                        Text("New note").font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundColor(theme.ink)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(theme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 26).frame(height: 58)
            .overlay(alignment: .bottom) { Divider().background(theme.line) }

            ScrollView {
                let cols = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
                LazyVGrid(columns: cols, spacing: 16) {
                    ForEach(MockData.notes) { note in
                        NoteCard(note: note)
                    }
                }
                .padding(26)
            }
        }
    }
}

struct NoteCard: View {
    @Environment(AppTheme.self) var theme
    let note: Note

    var body: some View {
        Button {
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(note.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.ink)
                    .lineLimit(2)

                Text(note.body)
                    .font(.system(size: 13)).lineSpacing(3)
                    .foregroundColor(theme.ink2)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    if let bid = note.bookId, let book = MockData.book(id: bid) {
                        HStack(spacing: 5) {
                            Image(systemName: "book").font(.system(size: 11))
                            Text(book.title).lineLimit(1)
                        }
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(theme.accentInk)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(theme.accentSoft)
                        .clipShape(Capsule())
                    } else {
                        Text("Idea")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(theme.ink2)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(theme.surface3)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text(note.date).font(.system(size: 11.5)).foregroundColor(theme.ink3)
                }
            }
            .padding(18)
            .frame(minHeight: 150, alignment: .topLeading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}
