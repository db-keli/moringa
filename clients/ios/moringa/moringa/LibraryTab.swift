import SwiftUI

struct LibraryTab: View {
    @Environment(AppTheme.self) var theme
    var openBook: (Book) -> Void
    var openSearch: () -> Void
    var openSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Library")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(theme.ink)
                    Spacer()
                    Button(action: openSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(theme.ink2)
                            .frame(width: 38, height: 38)
                            .background(theme.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 12)

                // Search bar
                Button(action: openSearch) {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15)).foregroundColor(theme.ink3)
                        Text("Search everything")
                            .font(.system(size: 15)).foregroundColor(theme.ink3)
                        Spacer()
                    }
                    .padding(.horizontal, 12).frame(height: 38)
                    .background(theme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .background(theme.paper)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Reading now card
                    let now = MockData.readingNow
                    Button { openBook(now) } label: {
                        MReadingNowCard(book: now)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    // All books
                    HStack {
                        Text("All Books").font(.system(size: 18, weight: .bold)).foregroundColor(theme.ink)
                        Spacer()
                        Text("\(MockData.books.count)").font(.system(size: 13)).foregroundColor(theme.ink3)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24).padding(.bottom, 14)

                    let cols = Array(repeating: GridItem(.flexible(), spacing: 18), count: 2)
                    LazyVGrid(columns: cols, spacing: 22) {
                        ForEach(MockData.books) { b in
                            Button { openBook(b) } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    BookCoverView(book: b)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(b.title)
                                            .font(.system(size: 13.5, weight: .semibold))
                                            .foregroundColor(theme.ink).lineLimit(2)
                                        Text(b.author)
                                            .font(.system(size: 12)).foregroundColor(theme.ink3)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

struct MReadingNowCard: View {
    @Environment(AppTheme.self) var theme
    let book: Book

    var body: some View {
        HStack(spacing: 16) {
            BookCoverView(book: book, small: true).frame(width: 74)

            VStack(alignment: .leading, spacing: 0) {
                Text("READING NOW")
                    .font(.system(size: 10.5, weight: .bold)).tracking(0.05)
                    .foregroundColor(theme.accentInk)
                Text(book.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(theme.ink)
                    .lineLimit(2).padding(.top, 5)
                Text(book.author)
                    .font(.system(size: 13)).foregroundColor(theme.ink2)
                    .padding(.top, 2)

                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(theme.surface3).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3).fill(theme.accent)
                            .frame(width: g.size.width * book.progress, height: 5)
                    }
                }
                .frame(height: 5).padding(.top, 12)

                Text("\(Int(book.progress * 100))% · \(MockData.readingNowChapter)")
                    .font(.system(size: 11.5)).foregroundColor(theme.ink3)
                    .lineLimit(1).padding(.top, 6)
            }
        }
        .padding(16)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}
