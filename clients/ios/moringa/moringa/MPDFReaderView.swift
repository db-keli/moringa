import SwiftUI
import PDFKit

struct MPDFReaderView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    let book: Book
    var onBack: () -> Void

    @State private var pdfDoc: PDFDocument? = nil
    @State private var loading = true
    @State private var errorMsg: String?
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

                    Text(book.title).font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.ink).lineLimit(1)

                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            if currentPage > 1 { /* pdfViewRef handles this via notification */ }
                        } label: {
                            Image(systemName: "chevron.left").font(.system(size: 13))
                                .foregroundColor(theme.ink2).frame(width: 34, height: 34)
                                .background(theme.surface).clipShape(Circle())
                                .overlay(Circle().stroke(theme.line, lineWidth: 1))
                        }.buttonStyle(.plain).disabled(currentPage <= 1)

                        Button {
                            if currentPage < totalPages { /* pdfViewRef handles this via notification */ }
                        } label: {
                            Image(systemName: "chevron.right").font(.system(size: 13))
                                .foregroundColor(theme.ink2).frame(width: 34, height: 34)
                                .background(theme.surface).clipShape(Circle())
                                .overlay(Circle().stroke(theme.line, lineWidth: 1))
                        }.buttonStyle(.plain).disabled(currentPage >= totalPages)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 58).padding(.bottom, 10)

                // ── Content ──────────────────────────────────────────────────
                if loading {
                    Spacer()
                    ProgressView("Loading PDF…").foregroundColor(theme.ink3)
                    Spacer()
                } else if let err = errorMsg {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 32)).foregroundColor(theme.ink3)
                        Text(err).font(.system(size: 14)).foregroundColor(theme.ink3).multilineTextAlignment(.center)
                        Button("Retry") { Task { await loadPDF() } }
                            .foregroundColor(theme.accentInk).buttonStyle(.plain)
                    }.padding(40)
                    Spacer()
                } else if let doc = pdfDoc {
                    VStack(spacing: 0) {
                        IOSPDFKitView(
                            document: doc,
                            isDark: theme.isDark,
                            onPageChanged: { cur, tot in
                                currentPage = cur
                                totalPages  = tot
                            }
                        )

                        // Footer
                        HStack(spacing: 12) {
                            Text("PDF")
                                .font(.system(size: 12)).foregroundColor(theme.ink3)

                            Spacer()

                            Text("p.\(currentPage) of \(totalPages)")
                                .font(.system(size: 11.5, design: .monospaced)).foregroundColor(theme.ink3)

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
        .task { await loadPDF() }
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
            if !store.authToken.isEmpty {
                req.setValue("Bearer \(store.authToken)", forHTTPHeaderField: "Authorization")
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

// MARK: - PDFKit UIView wrapper

struct IOSPDFKitView: UIViewRepresentable {
    let document: PDFDocument
    let isDark: Bool
    var onPageChanged: (Int, Int) -> Void

    func makeUIView(context: Context) -> PDFView {
        let pv = PDFView()
        pv.document = document
        pv.autoScales = true
        pv.displayMode = .singlePageContinuous
        pv.displaysPageBreaks = true
        pv.displayDirection = .vertical
        // Allow native pinch zoom
        pv.minScaleFactor = 0.5
        pv.maxScaleFactor = 4.0
        applyColors(isDark: isDark, to: pv)

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pv
        )
        context.coordinator.pdfView = pv
        context.coordinator.onPageChanged = onPageChanged
        return pv
    }

    func updateUIView(_ pv: PDFView, context: Context) {
        applyColors(isDark: isDark, to: pv)
    }

    private func applyColors(isDark: Bool, to pv: PDFView) {
        pv.backgroundColor = isDark ? UIColor(hex: "161B1C") : UIColor(hex: "FFFFFF")
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

extension UIColor {
    convenience init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        self.init(
            red:   CGFloat((n >> 16) & 0xFF) / 255,
            green: CGFloat((n >>  8) & 0xFF) / 255,
            blue:  CGFloat( n        & 0xFF) / 255,
            alpha: 1
        )
    }
}
