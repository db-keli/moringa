import SwiftUI
import PDFKit

struct PDFReaderView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    let book: Book
    var onBack: () -> Void

    @State private var pdfDoc: PDFDocument? = nil
    @State private var loading = true
    @State private var errorMsg: String?
    @State private var currentPage = 1
    @State private var totalPages  = 1
    @State private var pdfView: PDFView? = nil

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

                // Zoom out
                Button {
                    pdfView?.scaleFactor = max(0.25, (pdfView?.scaleFactor ?? 1) - 0.1)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 13)).foregroundColor(theme.ink2)
                        .frame(width: 30, height: 30)
                }.buttonStyle(.plain).help("Zoom out")

                // Zoom in
                Button {
                    pdfView?.scaleFactor = min(4.0, (pdfView?.scaleFactor ?? 1) + 0.1)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 13)).foregroundColor(theme.ink2)
                        .frame(width: 30, height: 30)
                }.buttonStyle(.plain).help("Zoom in")

                // Layout toggle
                Button {
                    let all = ReadingLayout.allCases
                    if let idx = all.firstIndex(of: theme.readingLayout) {
                        theme.readingLayout = all[(idx + 1) % all.count]
                    }
                    applyLayout()
                } label: {
                    Image(systemName: theme.readingLayout.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.readingLayout == .scroll ? theme.ink2 : theme.accent)
                        .frame(width: 34, height: 34)
                        .background(theme.readingLayout == .scroll ? Color.clear : theme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain).help(theme.readingLayout.label)

                // Page navigation
                Button { pdfView?.goToPreviousPage(nil) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13))
                }.buttonStyle(IconBtnStyle()).disabled(currentPage <= 1)

                Text("\(currentPage) / \(totalPages)")
                    .font(.system(size: 12)).foregroundColor(theme.ink3).frame(minWidth: 50)

                Button { pdfView?.goToNextPage(nil) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 13))
                }.buttonStyle(IconBtnStyle()).disabled(currentPage >= totalPages)
            }
            .padding(.horizontal, 18).frame(height: 54)
            .background(theme.reader)
            .overlay(alignment: .bottom) { Divider().background(theme.line) }

            // ── Content ──────────────────────────────────────────────────────
            if loading {
                Spacer()
                ProgressView("Loading PDF…").foregroundColor(theme.ink3)
                Spacer()
            } else if let err = errorMsg {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 32)).foregroundColor(theme.ink3)
                    Text(err).font(.system(size: 14)).foregroundColor(theme.ink3).multilineTextAlignment(.center)
                    Button("Retry") { Task { await loadPDF() } }.buttonStyle(PrimaryButtonStyle())
                }
                .padding(40)
                Spacer()
            } else if let doc = pdfDoc {
                VStack(spacing: 0) {
                    PDFKitView(
                        document: doc,
                        isDark: theme.isDark,
                        layout: theme.readingLayout,
                        onViewCreated: { pdfView = $0 },
                        onPageChanged: { cur, tot in
                            currentPage = cur
                            totalPages  = tot
                        }
                    )
                    .background(theme.reader)

                    // Footer
                    HStack(spacing: 12) {
                        Text("PDF")
                            .font(.system(size: 12)).foregroundColor(theme.ink3)

                        Spacer()

                        if theme.readingLayout == .paginated {
                            pageDotsView
                        } else {
                            Text("p.\(currentPage) of \(totalPages)")
                                .font(.system(size: 12, design: .monospaced)).foregroundColor(theme.ink3)
                        }

                        Spacer()

                        Text("\(Int(book.progress * 100))%")
                            .font(.system(size: 12)).foregroundColor(theme.ink3)
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .overlay(alignment: .top) { Divider().background(theme.line) }
                    .background(theme.reader)
                }
            }
        }
        .background(theme.reader)
        .task { await loadPDF() }
    }

    @ViewBuilder private var pageDotsView: some View {
        let visible = min(totalPages, 9)
        let dotPage = totalPages > 9
            ? Int(Double(currentPage - 1) / Double(totalPages - 1) * Double(visible - 1))
            : currentPage - 1
        HStack(spacing: 5) {
            ForEach(0..<visible, id: \.self) { i in
                Circle()
                    .fill(i == dotPage ? theme.accent : theme.ink3.opacity(0.35))
                    .frame(width: i == dotPage ? 7 : 5, height: i == dotPage ? 7 : 5)
                    .animation(.easeInOut(duration: 0.2), value: dotPage)
            }
        }
    }

    private func applyLayout() {
        guard let pv = pdfView else { return }
        switch theme.readingLayout {
        case .scroll:
            pv.displayMode = .singlePageContinuous
            pv.displaysPageBreaks = true
        case .paginated:
            pv.displayMode = .singlePage
            pv.displaysPageBreaks = false
        case .twoColumn:
            pv.displayMode = .twoUpContinuous
            pv.displaysPageBreaks = true
        }
    }

    private func loadPDF() async {
        loading = true; errorMsg = nil
        guard !store.serverURL.isEmpty else {
            await MainActor.run { errorMsg = "Server URL not configured"; loading = false }
            return
        }
        let base = store.serverURL.hasSuffix("/") ? String(store.serverURL.dropLast()) : store.serverURL
        guard let url = URL(string: "\(base)/books/\(book.id)/assets/original.pdf") else {
            await MainActor.run { errorMsg = "Invalid server URL"; loading = false }
            return
        }

        // Check local cache first
        let cacheURL = localCacheURL()
        if let cached = PDFDocument(url: cacheURL) {
            await MainActor.run {
                pdfDoc = cached
                totalPages = cached.pageCount
                loading = false
            }
            return
        }

        do {
            var req = URLRequest(url: url)
            if let token = UserDefaults.standard.string(forKey: "moringa.authToken"), !token.isEmpty {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            try data.write(to: cacheURL)
            let doc = PDFDocument(data: data)
            await MainActor.run {
                pdfDoc = doc
                totalPages = doc?.pageCount ?? 1
                loading = false
            }
        } catch {
            await MainActor.run { errorMsg = error.localizedDescription; loading = false }
        }
    }

    private func localCacheURL() -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("moringa/pdfs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(book.id).pdf")
    }
}

// MARK: - PDFKit NSView wrapper

struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument
    let isDark: Bool
    let layout: ReadingLayout
    var onViewCreated: (PDFView) -> Void
    var onPageChanged: (Int, Int) -> Void

    func makeNSView(context: Context) -> PDFView {
        let pv = PDFView()
        pv.document = document
        pv.autoScales = true
        pv.minScaleFactor = 0.25
        pv.maxScaleFactor = 4.0
        pv.displaysAsBook = false
        apply(layout: layout, to: pv)
        applyColors(isDark: isDark, to: pv)

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pv
        )
        context.coordinator.pdfView = pv
        context.coordinator.onPageChanged = onPageChanged
        onViewCreated(pv)
        return pv
    }

    func updateNSView(_ pv: PDFView, context: Context) {
        apply(layout: layout, to: pv)
        applyColors(isDark: isDark, to: pv)
    }

    private func apply(layout: ReadingLayout, to pv: PDFView) {
        switch layout {
        case .scroll:
            pv.displayMode = .singlePageContinuous
            pv.displaysPageBreaks = true
        case .paginated:
            pv.displayMode = .singlePage
            pv.displaysPageBreaks = false
        case .twoColumn:
            pv.displayMode = .twoUpContinuous
            pv.displaysPageBreaks = true
        }
    }

    private func applyColors(isDark: Bool, to pv: PDFView) {
        pv.backgroundColor = isDark ? NSColor(hex: "161B1C") : NSColor(hex: "FFFFFF")
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var pdfView: PDFView?
        var onPageChanged: ((Int, Int) -> Void)?

        @objc func pageChanged(_ note: Notification) {
            guard let pv = pdfView, let doc = pv.document,
                  let page = pv.currentPage else { return }
            let idx = doc.index(for: page)
            onPageChanged?(idx + 1, doc.pageCount)
        }
    }
}

extension NSColor {
    convenience init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        let r = CGFloat((n >> 16) & 0xFF) / 255
        let g = CGFloat((n >>  8) & 0xFF) / 255
        let b = CGFloat( n        & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
