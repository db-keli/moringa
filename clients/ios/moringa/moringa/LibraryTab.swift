import SwiftUI
import UniformTypeIdentifiers

struct LibraryTab: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    var openBook: (Book) -> Void
    var openSearch: () -> Void
    var openSettings: () -> Void

    @State private var showImporter = false
    @State private var importing    = false
    @State private var importError: String?
    @State private var showError    = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Library").font(.system(size: 30, weight: .bold)).foregroundColor(theme.ink)
                    Spacer()
                    Button(action: openSettings) {
                        Image(systemName: "gearshape").font(.system(size: 18))
                            .foregroundColor(theme.ink2).frame(width: 38, height: 38)
                            .background(theme.surface).clipShape(Circle())
                            .overlay(Circle().stroke(theme.line, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 12)

                Button(action: openSearch) {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundColor(theme.ink3)
                        Text("Search everything").font(.system(size: 15)).foregroundColor(theme.ink3)
                        Spacer()
                    }
                    .padding(.horizontal, 12).frame(height: 38)
                    .background(theme.surface2).clipShape(RoundedRectangle(cornerRadius: 11))
                }.buttonStyle(.plain).padding(.horizontal, 20).padding(.bottom, 8)
            }.background(theme.paper)

            if store.books.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let now = store.books.first(where: { $0.progress > 0 && $0.progress < 1 }) {
                            Button { openBook(now) } label: { MReadingNowCard(book: now) }
                                .buttonStyle(.plain).padding(.horizontal, 20).padding(.top, 14)
                        }

                        HStack {
                            Text("All Books").font(.system(size: 18, weight: .bold)).foregroundColor(theme.ink)
                            Spacer()
                            Text("\(store.books.count)").font(.system(size: 13)).foregroundColor(theme.ink3)
                        }.padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 14)

                        let cols = Array(repeating: GridItem(.flexible(), spacing: 18), count: 2)
                        LazyVGrid(columns: cols, spacing: 22) {
                            ForEach(store.books) { b in
                                Button { openBook(b) } label: {
                                    VStack(alignment: .leading, spacing: 9) {
                                        BookCoverView(book: b)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(b.title).font(.system(size: 13.5, weight: .semibold))
                                                .foregroundColor(theme.ink).lineLimit(2)
                                            Text(b.author).font(.system(size: 12)).foregroundColor(theme.ink3)
                                        }
                                    }
                                }.buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20).padding(.bottom, 30)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await doImport(url: url) }
        }
        .alert("Import failed", isPresented: $showError) {
            Button("OK") {}
        } message: { Text(importError ?? "") }
    }

    private func doImport(url: URL) async {
        importing = true
        defer { Task { @MainActor in importing = false } }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let title = url.deletingPathExtension().lastPathComponent
            try await store.importBook(title: title, author: "", fileURL: url)
        } catch { importError = error.localizedDescription; showError = true }
    }

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical").font(.system(size: 48)).foregroundColor(theme.ink3)
            Text("No books yet").font(.system(size: 18, weight: .semibold)).foregroundColor(theme.ink)
            Text(store.serverURL.isEmpty
                 ? "Configure your server in Settings."
                 : "Import an EPUB to get started.")
                .font(.system(size: 14)).foregroundColor(theme.ink3).multilineTextAlignment(.center)
            Button { showImporter = true } label: {
                HStack(spacing: 6) {
                    if importing { ProgressView().tint(.white) }
                    else { Image(systemName: "plus") }
                    Text("Import EPUB")
                }
                .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                .padding(.horizontal, 20).frame(height: 44)
                .background(theme.accent).clipShape(RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }
}

struct MReadingNowCard: View {
    @Environment(AppTheme.self) var theme
    let book: Book
    var body: some View {
        HStack(spacing: 16) {
            BookCoverView(book: book, small: true).frame(width: 74)
            VStack(alignment: .leading, spacing: 0) {
                Text("READING NOW").font(.system(size: 10.5, weight: .bold)).tracking(0.05)
                    .foregroundColor(theme.accentInk)
                Text(book.title).font(.system(size: 17, weight: .bold)).foregroundColor(theme.ink)
                    .lineLimit(2).padding(.top, 5)
                Text(book.author).font(.system(size: 13)).foregroundColor(theme.ink2).padding(.top, 2)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(theme.surface3).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3).fill(theme.accent)
                            .frame(width: g.size.width * book.progress, height: 5)
                    }
                }.frame(height: 5).padding(.top, 12)
                Text("\(Int(book.progress * 100))% complete")
                    .font(.system(size: 11.5)).foregroundColor(theme.ink3).padding(.top, 6)
            }
        }
        .padding(16).background(theme.surface).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}
