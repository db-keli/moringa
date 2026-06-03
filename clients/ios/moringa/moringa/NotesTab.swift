import SwiftUI

struct NotesTab: View {
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Text("Notes")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 8)
                    .background(theme.paper)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(MockData.notes) { n in
                            MNoteCard(note: n)
                                .padding(.horizontal, 20)
                        }
                        Spacer(minLength: 30)
                    }
                    .padding(.top, 12)
                }
            }

            // FAB
            Button { } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(theme.accent)
                    .clipShape(Circle())
                    .shadow(color: theme.accent.opacity(0.45), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 18).padding(.bottom, 10)
        }
    }
}

struct MNoteCard: View {
    @EnvironmentObject var theme: AppTheme
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title)
                .font(.system(size: 15.5, weight: .bold))
                .foregroundColor(theme.ink)

            Text(note.body)
                .font(.system(size: 13.5)).lineSpacing(3)
                .foregroundColor(theme.ink2)
                .lineLimit(3)

            HStack {
                if let bid = note.bookId, let b = MockData.book(id: bid) {
                    Text(b.title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(theme.accentInk)
                } else {
                    Text("Idea")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(theme.ink2)
                }
                Spacer()
                Text(note.date).font(.system(size: 11.5)).foregroundColor(theme.ink3)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}
