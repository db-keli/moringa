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
    @State private var hlMode  = false
    @State private var hlColor: HLColor = .yellow
    @State private var currentPage = 1
    @State private var totalPages  = 1

    var body: some View {
        ZStack {
            theme.reader.ignoresSafeArea()
            VStack(spacing: 0) {
                // ── Toolbar ──────────────────────────────────────────────────
                HStack(spacing: 10) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.ink2).frame(width: 38, height: 38)
                            .background(theme.surface).clipShape(Circle())
                            .overlay(Circle().stroke(theme.line, lineWidth: 1))
                    }.buttonStyle(.plain)

                    Spacer()

                    if hlMode {
                        HStack(spacing: 10) {
                            ForEach(HLColor.allCases, id: \.self) { c in
                                Button { hlColor = c } label: {
                                    Circle().fill(c.color)
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            Circle().stroke(theme.ink.opacity(hlColor == c ? 0.6 : 0), lineWidth: 2)
                                                .padding(1)
                                        )
                                }.buttonStyle(.plain)
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else {
                        Text(book.title).font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.ink).lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        // Font size controls
                        Button { theme.readerSize = max(12, theme.readerSize - 2) } label: {
                            Image(systemName: "textformat.size.smaller").font(.system(size: 14))
                                .foregroundColor(theme.ink2).frame(width: 34, height: 34)
                                .background(theme.surface).clipShape(Circle())
                                .overlay(Circle().stroke(theme.line, lineWidth: 1))
                        }.buttonStyle(.plain)
                        Button { theme.readerSize = min(32, theme.readerSize + 2) } label: {
                            Image(systemName: "textformat.size.larger").font(.system(size: 14))
                                .foregroundColor(theme.ink2).frame(width: 34, height: 34)
                                .background(theme.surface).clipShape(Circle())
                                .overlay(Circle().stroke(theme.line, lineWidth: 1))
                        }.buttonStyle(.plain)

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { hlMode.toggle() }
                        } label: {
                            Image(systemName: "highlighter").font(.system(size: 15, weight: .medium))
                                .foregroundColor(hlMode ? theme.accent : theme.ink2)
                                .frame(width: 38, height: 38)
                                .background(hlMode ? theme.accentSoft : theme.surface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(theme.line, lineWidth: 1))
                        }.buttonStyle(.plain)

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
                }
                .padding(.horizontal, 16).padding(.top, 58).padding(.bottom, 10)

                // ── Content ──────────────────────────────────────────────────
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
                    VStack(spacing: 0) {
                        ZStack {
                            let poolChunks = [currentChunk - 1, currentChunk, currentChunk + 1].filter { chunks.indices.contains($0) }
                            ForEach(poolChunks, id: \.self) { i in
                                WebReaderView(
                                    chapterURL: chapterURL(for: chunks[i]),
                                    html: chunks[i].html,
                                    isDark: theme.isDark,
                                    fontSize: theme.readerSize,
                                    highlights: i == currentChunk ? chunkHighlights : []
                                ) { pct in
                                    guard i == currentChunk else { return }
                                    let overall = (Double(i) + pct) / Double(chunks.count)
                                    store.savePosition(bookId: book.id, chunkIndex: i, scrollPct: overall)
                                } onTextSelected: { payload in
                                    guard i == currentChunk, hlMode,
                                          let data = payload.data(using: .utf8),
                                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                          let text = json["text"] as? String, !text.isEmpty else { return }
                                    let loc = buildLoc(payload: payload, chunk: i)
                                    store.addHighlight(bookId: book.id, color: hlColor, text: text, loc: loc)
                                } onChapterLink: { filename in
                                    guard i == currentChunk else { return }
                                    navigateToChapter(filename: filename)
                                } onPageInfo: { cur, tot in
                                    guard i == currentChunk else { return }
                                    currentPage = cur
                                    totalPages  = tot
                                }
                                .opacity(i == currentChunk ? 1 : 0)
                                .allowsHitTesting(i == currentChunk)
                            }
                        }

                        // Footer bar
                        HStack(spacing: 12) {
                            let chTitle = chunks[currentChunk].title.isEmpty
                                ? "Chapter \(currentChunk + 1)"
                                : chunks[currentChunk].title
                            Text(chTitle)
                                .font(.system(size: 12)).foregroundColor(theme.ink3)
                                .lineLimit(1)

                            Spacer()

                            if theme.readingLayout == .paginated {
                                pageDotsView
                            } else {
                                Text("p.\(currentPage) of \(totalPages)")
                                    .font(.system(size: 11.5, design: .monospaced)).foregroundColor(theme.ink3)
                            }

                            Spacer()

                            Text("\(Int(book.progress * 100))%")
                                .font(.system(size: 12)).foregroundColor(theme.ink3)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 44).overlay(alignment: .top) { Divider().background(theme.line) }
                    }
                }
            }
        }
        .task { await load() }
    }

    // ── Page dots (paginated mode) ────────────────────────────────────────────

    @ViewBuilder private var pageDotsView: some View {
        let visible = min(totalPages, 9)
        let dotPage = totalPages > 9
            ? Int(Double(currentPage - 1) / Double(totalPages - 1) * Double(visible - 1))
            : currentPage - 1
        HStack(spacing: 6) {
            ForEach(0..<visible, id: \.self) { i in
                Circle()
                    .fill(i == dotPage ? theme.accent : theme.ink3.opacity(0.35))
                    .frame(width: i == dotPage ? 8 : 5, height: i == dotPage ? 8 : 5)
                    .animation(.easeInOut(duration: 0.2), value: dotPage)
            }
        }
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
