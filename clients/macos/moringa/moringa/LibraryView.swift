import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    var openBook: (Book) -> Void

    @State private var filter: String = "All"
    @State private var showImporter = false
    @State private var importing = false
    @State private var importError: String?
    @State private var showImportAlert = false

    let filters = ["All", "Reading Now", "Finished", "Not Started"]

    var shown: [Book] {
        switch filter {
        case "Reading Now":  return store.books.filter { $0.progress > 0 && $0.progress < 1 }
        case "Finished":     return store.books.filter { $0.progress >= 1 }
        case "Not Started":  return store.books.filter { $0.progress == 0 }
        default:             return store.books
        }
    }

    var readingNow: Book? { store.books.first(where: { $0.progress > 0 && $0.progress < 1 }) }

    var body: some View {
        VStack(spacing: 0) {
            // Topbar
            HStack {
                Text("Library").font(.system(size: 20, weight: .bold)).foregroundColor(theme.ink)
                Spacer()
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { f in
                        Button(f) { filter = f }
                            .buttonStyle(ChipStyle(active: filter == f))
                    }
                }
                Button {
                    showImporter = true
                } label: {
                    HStack(spacing: 6) {
                        if importing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                        }
                        Text("Import Book")
                    }
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .disabled(importing)
            }
            .padding(.horizontal, 26).frame(height: 58)
            .overlay(alignment: .bottom) { Divider().background(theme.line) }

            if store.books.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let now = readingNow {
                            ReadingNowCard(book: now, openBook: openBook)
                                .padding(26)
                        }

                        HStack {
                            Text("Library").font(.system(size: 15, weight: .bold)).foregroundColor(theme.ink)
                            Text("\(shown.count) books").font(.system(size: 13)).foregroundColor(theme.ink3)
                            Spacer()
                        }
                        .padding(.horizontal, 26).padding(.bottom, 16)

                        let cols = Array(repeating: GridItem(.flexible(), spacing: 22), count: 6)
                        LazyVGrid(columns: cols, spacing: 26) {
                            ForEach(shown) { book in
                                Button { openBook(book) } label: { BookGridCell(book: book) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 26).padding(.bottom, 40)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data, .pdf],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await doImport(url: url) }
        }
        .alert("Import failed", isPresented: $showImportAlert) {
            Button("OK") {}
        } message: {
            Text(importError ?? "Unknown error")
        }
    }

    private func doImport(url: URL) async {
        importing = true
        defer { Task { @MainActor in importing = false } }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let title = url.deletingPathExtension().lastPathComponent
            try await store.importBook(title: title, author: "", fileURL: url)
        } catch {
            importError = error.localizedDescription
            showImportAlert = true
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48)).foregroundColor(theme.ink3)
            Text("No books yet")
                .font(.system(size: 18, weight: .semibold)).foregroundColor(theme.ink)
            Text(store.serverURL.isEmpty
                 ? "Configure your server in Settings, then import an EPUB or PDF."
                 : "Import an EPUB or PDF to get started.")
                .font(.system(size: 14)).foregroundColor(theme.ink3)
                .multilineTextAlignment(.center)
            Button("Import Book") { showImporter = true }
                .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Reading Now Card

struct ReadingNowCard: View {
    @Environment(AppTheme.self) var theme
    let book: Book
    var openBook: (Book) -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button { openBook(book) } label: {
                BookCoverView(book: book).frame(width: 128)
            }.buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 0) {
                Text("READING NOW")
                    .font(.system(size: 11, weight: .bold)).tracking(0.06)
                    .foregroundColor(theme.accentInk)
                Text(book.title)
                    .font(.system(size: 23, weight: .bold)).foregroundColor(theme.ink)
                    .padding(.top, 7)
                Text(book.author)
                    .font(.system(size: 14)).foregroundColor(theme.ink2).padding(.top, 2)

                Spacer(minLength: 14)

                HStack(spacing: 16) {
                    Button { openBook(book) } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "book")
                            Text("Continue reading")
                        }
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(theme.accent).clipShape(RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(theme.surface3).frame(height: 5)
                                RoundedRectangle(cornerRadius: 3).fill(theme.accent)
                                    .frame(width: g.size.width * book.progress, height: 5)
                            }
                        }.frame(height: 5)
                        Text("\(Int(book.progress * 100))% complete")
                            .font(.system(size: 12)).foregroundColor(theme.ink3)
                    }.frame(maxWidth: 280)
                }
            }
        }
        .padding(22)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Book Grid Cell

struct BookGridCell: View {
    @Environment(AppTheme.self) var theme
    let book: Book
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BookCoverView(book: book)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 13.5, weight: .semibold)).foregroundColor(theme.ink)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(book.author).font(.system(size: 12)).foregroundColor(theme.ink3)
                if book.progress > 0 && book.progress < 1 {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(theme.surface3).frame(height: 3)
                            RoundedRectangle(cornerRadius: 2).fill(theme.accent)
                                .frame(width: g.size.width * book.progress, height: 3)
                        }
                    }.frame(height: 3).padding(.top, 7)
                }
            }
        }
    }
}

// MARK: - Button styles

struct ChipStyle: ButtonStyle {
    @Environment(AppTheme.self) var theme
    var active: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(active ? theme.paper : theme.ink2)
            .padding(.horizontal, 13).frame(height: 30)
            .background(active ? theme.ink : theme.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(theme.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(AppTheme.self) var theme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14).frame(height: 34)
            .background(theme.accent).clipShape(RoundedRectangle(cornerRadius: 9))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
