import SwiftUI

struct LibraryView: View {
    @Environment(AppTheme.self) var theme
    var openBook: (Book) -> Void
    @State private var filter: String = "All"

    let filters = ["All", "Reading Now", "Finished", "Not Started"]

    var shown: [Book] {
        switch filter {
        case "Reading Now":  return MockData.books.filter { $0.progress > 0 && $0.progress < 1 }
        case "Finished":     return MockData.books.filter { $0.progress == 1 }
        case "Not Started":  return MockData.books.filter { $0.progress == 0 }
        default:             return MockData.books
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Topbar
            HStack {
                Text("Library").font(.system(size: 20, weight: .bold)).foregroundColor(theme.ink)
                Spacer()
                // filter chips
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { f in
                        Button(f) { filter = f }
                            .buttonStyle(ChipStyle(active: filter == f))
                    }
                }
            }
            .padding(.horizontal, 26)
            .frame(height: 58)
            .background(theme.paper)
            .overlay(alignment: .bottom) { Divider().background(theme.line) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Reading now
                    ReadingNowCard(book: MockData.readingNow, openBook: openBook)
                        .padding(26)

                    // Section header
                    HStack {
                        Text("Library").font(.system(size: 15, weight: .bold)).foregroundColor(theme.ink)
                        Text("\(shown.count) books").font(.system(size: 13)).foregroundColor(theme.ink3)
                        Spacer()
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 16)

                    // Grid
                    let cols = Array(repeating: GridItem(.flexible(), spacing: 22), count: 6)
                    LazyVGrid(columns: cols, spacing: 26) {
                        ForEach(shown) { book in
                            Button { openBook(book) } label: {
                                BookGridCell(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Reading Now Card

struct ReadingNowCard: View {
    @Environment(AppTheme.self) var theme
    let book: Book
    var openBook: (Book) -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button { openBook(book) } label: {
                BookCoverView(book: book).frame(width: 128)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 0) {
                Text("READING NOW")
                    .font(.system(size: 11, weight: .bold)).tracking(0.06)
                    .foregroundColor(theme.accentInk)
                Text(book.title)
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(theme.ink)
                    .padding(.top, 7)
                Text(book.author)
                    .font(.system(size: 14))
                    .foregroundColor(theme.ink2)
                    .padding(.top, 2)

                HStack {
                    Rectangle()
                        .fill(theme.accentInk)
                        .frame(width: 2)
                        .padding(.vertical, 2)
                    Text("\u{201C}\(MockData.readingNowQuote)\u{201D}")
                        .font(.system(size: 14.5))
                        .foregroundColor(theme.ink2)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 14)

                Spacer(minLength: 14)

                HStack(spacing: 16) {
                    Button { openBook(book) } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "book")
                            Text("Continue reading")
                        }
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(theme.surface3).frame(height: 5)
                                RoundedRectangle(cornerRadius: 3).fill(theme.accent)
                                    .frame(width: g.size.width * book.progress, height: 5)
                            }
                        }
                        .frame(height: 5)
                        Text("\(Int(book.progress * 100))% · \(MockData.readingNowChapter)")
                            .font(.system(size: 12)).foregroundColor(theme.ink3)
                    }
                    .frame(maxWidth: 280)
                }
            }
        }
        .padding(22)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Book Grid Cell

struct BookGridCell: View {
    @Environment(AppTheme.self) var theme
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BookCoverView(book: book)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(theme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(book.author)
                    .font(.system(size: 12))
                    .foregroundColor(theme.ink3)
                if book.progress > 0 && book.progress < 1 {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(theme.surface3).frame(height: 3)
                            RoundedRectangle(cornerRadius: 2).fill(theme.accent)
                                .frame(width: g.size.width * book.progress, height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.top, 7)
                }
            }
        }
    }
}

// MARK: - Chip Button Style

struct ChipStyle: ButtonStyle {
    @Environment(AppTheme.self) var theme
    var active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(active ? theme.paper : theme.ink2)
            .padding(.horizontal, 13)
            .frame(height: 30)
            .background(active ? theme.ink : theme.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(theme.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
