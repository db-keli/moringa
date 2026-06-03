import SwiftUI

struct HighlightsView: View {
    @EnvironmentObject var theme: AppTheme
    @State private var filter: String = "all"

    var byBook: [String: [Highlight]] {
        Dictionary(grouping: MockData.highlights, by: \.bookId)
    }

    var shown: [Highlight] {
        if filter == "all" { return MockData.highlights }
        if filter.hasPrefix("c:") {
            let c = String(filter.dropFirst(2))
            return MockData.highlights.filter { $0.color.rawValue == c }
        }
        return MockData.highlights.filter { $0.bookId == filter }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sub-nav
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    subLabel("Collections")
                    subItem(id: "all", label: "All highlights",
                            icon: "highlighter", count: MockData.highlights.count)

                    subLabel("By colour")
                    ForEach(HLColor.allCases, id: \.self) { c in
                        subColorItem(c)
                    }

                    subLabel("By book")
                    ForEach(byBook.keys.sorted(), id: \.self) { bid in
                        if let book = MockData.book(id: bid) {
                            subBookItem(book: book, count: byBook[bid]?.count ?? 0)
                        }
                    }
                }
                .padding(10)
            }
            .frame(width: 232)
            .background(theme.paper)
            .overlay(alignment: .trailing) { Divider().background(theme.line) }

            // Highlights list
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(shown) { h in
                        HLCard(highlight: h)
                    }
                }
                .padding(26)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(theme.paper)
        }
    }

    @ViewBuilder
    private func subLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold)).tracking(0.06)
            .foregroundColor(theme.ink3)
            .padding(.horizontal, 10).padding(.top, 6).padding(.bottom, 4)
    }

    @ViewBuilder
    private func subItem(id: String, label: String, icon: String, count: Int) -> some View {
        Button { filter = id } label: {
            HStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 13)).frame(width: 16)
                Text(label).font(.system(size: 13.5, weight: filter == id ? .semibold : .medium))
                Spacer()
                Text("\(count)").font(.system(size: 12)).foregroundColor(theme.ink3)
            }
            .foregroundColor(filter == id ? theme.ink : theme.ink2)
            .padding(.horizontal, 10).frame(height: 32)
            .background(filter == id ? theme.surface2 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func subColorItem(_ c: HLColor) -> some View {
        let fid = "c:\(c.rawValue)"
        Button { filter = fid } label: {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 2).fill(c.color)
                    .frame(width: 9, height: 9)
                Text(c.label).font(.system(size: 13.5, weight: filter == fid ? .semibold : .medium))
                Spacer()
                Text("\(MockData.highlights.filter { $0.color == c }.count)")
                    .font(.system(size: 12)).foregroundColor(theme.ink3)
            }
            .foregroundColor(filter == fid ? theme.ink : theme.ink2)
            .padding(.horizontal, 10).frame(height: 32)
            .background(filter == fid ? theme.surface2 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func subBookItem(book: Book, count: Int) -> some View {
        Button { filter = book.id } label: {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 2).fill(book.color)
                    .frame(width: 9, height: 9)
                Text(book.title)
                    .font(.system(size: 13.5, weight: filter == book.id ? .semibold : .medium))
                    .lineLimit(1)
                Spacer()
                Text("\(count)").font(.system(size: 12)).foregroundColor(theme.ink3)
            }
            .foregroundColor(filter == book.id ? theme.ink : theme.ink2)
            .padding(.horizontal, 10).frame(height: 32)
            .background(filter == book.id ? theme.surface2 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Highlight Card

struct HLCard: View {
    @EnvironmentObject var theme: AppTheme
    let highlight: Highlight

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12).fill(theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.line, lineWidth: 1))

                HStack(spacing: 0) {
                    // color bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(highlight.color.color)
                        .frame(width: 3)
                        .padding(.vertical, 14)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(highlight.text)
                            .font(.system(size: 16)).lineSpacing(5)
                            .foregroundColor(theme.ink)
                            .padding(.top, 18)

                        HStack(spacing: 10) {
                            if let b = MockData.book(id: highlight.bookId) {
                                Text(b.title).font(.system(size: 12.5, weight: .semibold)).foregroundColor(theme.ink2)
                                Text("·").foregroundColor(theme.ink3)
                                Text(b.author).font(.system(size: 12.5)).foregroundColor(theme.ink3)
                                Text("·").foregroundColor(theme.ink3)
                            }
                            Text(highlight.loc).font(.system(size: 12.5)).foregroundColor(theme.ink3)
                            Spacer()
                            Text(highlight.date).font(.system(size: 12.5)).foregroundColor(theme.ink3)
                        }
                        .padding(.top, 13).padding(.bottom, highlight.note == nil ? 18 : 11)

                        if let note = highlight.note {
                            Text(note)
                                .font(.system(size: 13.5)).lineSpacing(3)
                                .foregroundColor(theme.ink2)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(theme.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(.bottom, 18)
                        }
                    }
                    .padding(.leading, 14).padding(.trailing, 20)
                }
            }
        }
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}
