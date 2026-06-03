import SwiftUI

struct HighlightsTab: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store

    var body: some View {
        VStack(spacing: 0) {
            Text("Highlights").font(.system(size: 30, weight: .bold)).foregroundColor(theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 8)
                .background(theme.paper)

            if store.highlights.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "highlighter").font(.system(size: 40)).foregroundColor(theme.ink3)
                    Text("No highlights yet").font(.system(size: 17, weight: .semibold)).foregroundColor(theme.ink)
                    Text("Highlights made while reading appear here.")
                        .font(.system(size: 14)).foregroundColor(theme.ink3).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.highlights) { h in
                            MHLCard(highlight: h, book: store.book(id: h.bookId))
                                .padding(.horizontal, 20).padding(.top, 12)
                        }
                        Spacer(minLength: 30)
                    }
                }
            }
        }
    }
}

struct MHLCard: View {
    @Environment(AppTheme.self) var theme
    let highlight: Highlight
    let book: Book?
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 14).fill(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.line, lineWidth: 1))
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3).fill(highlight.color.color)
                    .frame(width: 3).padding(.vertical, 14)
                VStack(alignment: .leading, spacing: 0) {
                    Text(highlight.text).font(.system(size: 15.5)).lineSpacing(4)
                        .foregroundColor(theme.ink).padding(.top, 16)
                    HStack {
                        if let b = book {
                            Text(b.title).font(.system(size: 12, weight: .semibold)).foregroundColor(theme.ink2)
                            Text("·").foregroundColor(theme.ink3)
                        }
                        if !highlight.loc.isEmpty {
                            Text(highlight.loc).font(.system(size: 12)).foregroundColor(theme.ink3)
                        }
                        Spacer()
                        Text(highlight.createdAt.prefix(10)).font(.system(size: 12)).foregroundColor(theme.ink3)
                    }.padding(.top, 10).padding(.bottom, 16)

                    if let note = highlight.note, !note.isEmpty {
                        Text(note).font(.system(size: 13)).foregroundColor(theme.ink2)
                            .padding(10).background(theme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 8)).padding(.bottom, 14)
                    }
                }.padding(.leading, 12).padding(.trailing, 16)
            }
        }.shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}
