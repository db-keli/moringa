import SwiftUI

struct HighlightsTab: View {
    @Environment(AppTheme.self) var theme

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading) {
                Text("Highlights")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(theme.ink)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 8)
            }
            .background(theme.paper)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(MockData.highlights) { h in
                        MHLCard(highlight: h)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }
                    Spacer(minLength: 30)
                }
            }
        }
    }
}

struct MHLCard: View {
    @Environment(AppTheme.self) var theme
    let highlight: Highlight

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 14).fill(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.line, lineWidth: 1))

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(highlight.color.color)
                    .frame(width: 3)
                    .padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 0) {
                    Text(highlight.text)
                        .font(.system(size: 15.5)).lineSpacing(4)
                        .foregroundColor(theme.ink)
                        .padding(.top, 16)

                    HStack {
                        if let b = MockData.book(id: highlight.bookId) {
                            Text(b.title).font(.system(size: 12, weight: .semibold)).foregroundColor(theme.ink2)
                        }
                        Text("·").foregroundColor(theme.ink3)
                        Text(highlight.loc).font(.system(size: 12)).foregroundColor(theme.ink3)
                        Spacer()
                        Text(highlight.date).font(.system(size: 12)).foregroundColor(theme.ink3)
                    }
                    .padding(.top, 10).padding(.bottom, 16)
                }
                .padding(.leading, 12).padding(.trailing, 16)
            }
        }
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}
