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
    @State private var hlMode  = false
    @State private var hlColor: HLColor = .yellow

    var body: some View {
        VStack(spacing: 0) {
            // ── Toolbar ──────────────────────────────────────────────────────
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

                if hlMode {
                    HStack(spacing: 8) {
                        ForEach(HLColor.allCases, id: \.self) { c in
                            Button { hlColor = c } label: {
                                Circle().fill(c.color)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle().stroke(theme.ink.opacity(hlColor == c ? 0.7 : 0), lineWidth: 2)
                                            .padding(1)
                                    )
                            }.buttonStyle(.plain).help(c.label)
                        }
                    }
                    .padding(.horizontal, 6)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                Button { withAnimation(.easeInOut(duration: 0.15)) { hlMode.toggle() } } label: {
                    Image(systemName: "highlighter")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(hlMode ? theme.accent : theme.ink2)
                        .frame(width: 34, height: 34)
                        .background(hlMode ? theme.accentSoft : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain).help(hlMode ? "Stop highlighting" : "Highlight text")

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
            }
            .padding(.horizontal, 18).frame(height: 54)
            .background(theme.reader)
            .overlay(alignment: .bottom) { Divider().background(theme.line) }

            // ── Content ──────────────────────────────────────────────────────
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
                VStack(spacing: 0) {
                    WebReaderView(
                        chapterURL: chapterURL(for: chunks[currentChunk]),
                        html: chunks[currentChunk].html,
                        isDark: theme.isDark,
                        fontSize: theme.readerSize,
                        highlights: chunkHighlights
                    ) { pct in
                        let overall = (Double(currentChunk) + pct) / Double(chunks.count)
                        store.savePosition(bookId: book.id, chunkIndex: currentChunk, scrollPct: overall)
                    } onTextSelected: { payload in
                        guard hlMode,
                              let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let text = json["text"] as? String, !text.isEmpty else { return }
                        let loc = buildLoc(payload: payload, chunk: currentChunk)
                        store.addHighlight(bookId: book.id, color: hlColor, text: text, loc: loc)
                    } onChapterLink: { filename in
                        navigateToChapter(filename: filename)
                    }
                    .background(theme.reader)

                    HStack {
                        Text("\(Int(book.progress * 100))% · \(chunks[currentChunk].title.isEmpty ? "Chapter \(currentChunk + 1)" : chunks[currentChunk].title)")
                            .font(.system(size: 12)).foregroundColor(theme.ink3)
                    }
                    .frame(height: 40)
                    .overlay(alignment: .top) { Divider().background(theme.line) }
                    .background(theme.reader)
                }
            }
        }
        .background(theme.reader)
        .task { await loadChunks() }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func chapterURL(for chunk: BookChunk) -> URL? {
        guard !store.serverURL.isEmpty, !chunk.path.isEmpty else { return nil }
        let base = store.serverURL.hasSuffix("/") ? String(store.serverURL.dropLast()) : store.serverURL
        return URL(string: "\(base)/books/\(book.id)/assets/\(chunk.path)")
    }

    private func navigateToChapter(filename: String) {
        if let idx = chunks.firstIndex(where: { $0.path == filename || $0.path.hasSuffix("/\(filename)") }) {
            currentChunk = idx
        }
    }

    private var chunkHighlights: [Highlight] {
        store.highlights.filter { h in
            guard h.bookId == book.id else { return false }
            if let data = h.loc.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let chunk = json["chunk"] as? Int {
                return chunk == currentChunk
            }
            return false
        }
    }

    private func buildLoc(payload: String, chunk: Int) -> String {
        guard let data = payload.data(using: .utf8),
              var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return payload
        }
        dict["chunk"] = chunk
        guard let out = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: out, encoding: .utf8) else { return payload }
        return str
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
