import SwiftUI

struct ReaderView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    let book: Book
    var onBack: () -> Void

    @State private var chunks: [BookChunk] = []
    @State private var currentChunk = 0
    @State private var loading = true
    @State private var errorMsg: String?
    @State private var showHLPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium))
                }.buttonStyle(IconBtnStyle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(book.title).font(.system(size: 13.5, weight: .semibold)).foregroundColor(theme.ink)
                    if !book.author.isEmpty {
                        Text(book.author).font(.system(size: 12)).foregroundColor(theme.ink3)
                    }
                }
                Spacer()

                // Chapter navigation
                if !chunks.isEmpty {
                    Text("\(currentChunk + 1) / \(chunks.count)")
                        .font(.system(size: 12)).foregroundColor(theme.ink3)
                    Button { if currentChunk > 0 { currentChunk -= 1 } } label: {
                        Image(systemName: "chevron.left").font(.system(size: 13))
                    }.buttonStyle(IconBtnStyle()).disabled(currentChunk == 0)
                    Button { if currentChunk < chunks.count - 1 { currentChunk += 1 } } label: {
                        Image(systemName: "chevron.right").font(.system(size: 13))
                    }.buttonStyle(IconBtnStyle()).disabled(currentChunk == chunks.count - 1)
                }

                Button { } label: { Image(systemName: "textformat.size").font(.system(size: 14)) }
                    .buttonStyle(IconBtnStyle())
            }
            .padding(.horizontal, 18).frame(height: 54)
            .background(theme.reader)
            .overlay(alignment: .bottom) { Divider().background(theme.line) }

            // Content
            if loading {
                Spacer()
                ProgressView("Loading book…").foregroundColor(theme.ink3)
                Spacer()
            } else if let err = errorMsg {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 32)).foregroundColor(theme.ink3)
                    Text(err).font(.system(size: 14)).foregroundColor(theme.ink3).multilineTextAlignment(.center)
                    Button("Retry") { Task { await loadChunks() } }.buttonStyle(PrimaryButtonStyle())
                }
                .padding(40)
                Spacer()
            } else if !chunks.isEmpty {
                WebReaderView(
                    html: chunks[currentChunk].html,
                    isDark: theme.isDark,
                    fontSize: theme.readerSize
                ) { pct in
                    let overall = (Double(currentChunk) + pct) / Double(chunks.count)
                    store.savePosition(bookId: book.id, chunkIndex: currentChunk, scrollPct: overall)
                }
                .background(theme.reader)

                // Footer
                HStack {
                    Text("\(Int(book.progress * 100))% · \(chunks[currentChunk].title.isEmpty ? "Chapter \(currentChunk + 1)" : chunks[currentChunk].title)")
                        .font(.system(size: 12)).foregroundColor(theme.ink3)
                }
                .frame(height: 40)
                .overlay(alignment: .top) { Divider().background(theme.line) }
                .background(theme.reader)
            }
        }
        .background(theme.reader)
        .task { await loadChunks() }
    }

    private func loadChunks() async {
        loading = true
        errorMsg = nil
        do {
            let c = try await store.chunks(for: book)
            let state = store.readingState(for: book)
            await MainActor.run {
                chunks = c
                currentChunk = min(state.chunkIndex, max(0, c.count - 1))
                loading = false
            }
        } catch {
            await MainActor.run {
                errorMsg = error.localizedDescription
                loading = false
            }
        }
    }
}

// MARK: - Icon Button Style

struct IconBtnStyle: ButtonStyle {
    @Environment(AppTheme.self) var theme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(theme.ink2)
            .frame(width: 34, height: 34)
            .background(configuration.isPressed ? theme.surface2 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
