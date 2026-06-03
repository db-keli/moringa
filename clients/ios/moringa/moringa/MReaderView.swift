import SwiftUI

struct MReaderView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    let book: Book
    var onBack: () -> Void

    @State private var chunks: [BookChunk] = []
    @State private var currentChunk = 0
    @State private var loading = true
    @State private var errorMsg: String?

    var body: some View {
        ZStack {
            theme.reader.ignoresSafeArea()
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 10) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.ink2).frame(width: 38, height: 38)
                            .background(theme.surface).clipShape(Circle())
                            .overlay(Circle().stroke(theme.line, lineWidth: 1))
                    }.buttonStyle(.plain)

                    Spacer()
                    Text(book.title).font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.ink).lineLimit(1)
                    Spacer()

                    if !chunks.isEmpty {
                        HStack(spacing: 4) {
                            Button { if currentChunk > 0 { currentChunk -= 1 } } label: {
                                Image(systemName: "chevron.left").font(.system(size: 13))
                            }.buttonStyle(.plain).foregroundColor(theme.ink2).disabled(currentChunk == 0)

                            Text("\(currentChunk+1)/\(chunks.count)")
                                .font(.system(size: 12)).foregroundColor(theme.ink3)

                            Button { if currentChunk < chunks.count-1 { currentChunk += 1 } } label: {
                                Image(systemName: "chevron.right").font(.system(size: 13))
                            }.buttonStyle(.plain).foregroundColor(theme.ink2).disabled(currentChunk == chunks.count-1)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 58).padding(.bottom, 10)

                if loading {
                    Spacer()
                    ProgressView("Loading…").foregroundColor(theme.ink3)
                    Spacer()
                } else if let err = errorMsg {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 32)).foregroundColor(theme.ink3)
                        Text(err).font(.system(size: 14)).foregroundColor(theme.ink3).multilineTextAlignment(.center)
                        Button("Retry") { Task { await load() } }
                            .foregroundColor(theme.accentInk).buttonStyle(.plain)
                    }.padding(40)
                    Spacer()
                } else if !chunks.isEmpty {
                    WebReaderView(html: chunks[currentChunk].html,
                                  isDark: theme.isDark,
                                  fontSize: theme.readerSize) { pct in
                        let overall = (Double(currentChunk) + pct) / Double(chunks.count)
                        store.savePosition(bookId: book.id, chunkIndex: currentChunk, scrollPct: overall)
                    }

                    HStack {
                        Text("\(Int(book.progress * 100))% · \(chunks[currentChunk].title.isEmpty ? "Chapter \(currentChunk+1)" : chunks[currentChunk].title)")
                            .font(.system(size: 12)).foregroundColor(theme.ink3)
                    }
                    .frame(height: 44).overlay(alignment: .top) { Divider().background(theme.line) }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        loading = true; errorMsg = nil
        do {
            let c = try await store.chunks(for: book)
            let state = store.readingState(for: book)
            await MainActor.run {
                chunks = c
                currentChunk = min(state.chunkIndex, max(0, c.count-1))
                loading = false
            }
        } catch {
            await MainActor.run { errorMsg = error.localizedDescription; loading = false }
        }
    }
}
