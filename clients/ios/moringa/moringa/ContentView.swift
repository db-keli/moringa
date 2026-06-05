import SwiftUI

enum MTab { case library, highlights, notes, drafts }

enum Overlay: Identifiable {
    case reader(Book), editor(Draft), search, settings
    var id: String {
        switch self {
        case .reader(let b): return "reader-\(b.id)"
        case .editor(let d): return "editor-\(d.id)"
        case .search:        return "search"
        case .settings:      return "settings"
        }
    }
}

struct ContentView: View {
    @Environment(AppTheme.self) var theme
    @State private var tab: MTab = .library
    @State private var overlay: Overlay? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Tab content
                Group {
                    switch tab {
                    case .library:
                        LibraryTab(
                            openBook:     { overlay = .reader($0) },
                            openSearch:   { overlay = .search },
                            openSettings: { overlay = .settings }
                        )
                    case .highlights:
                        HighlightsTab()
                    case .notes:
                        NotesTab()
                    case .drafts:
                        DraftsTab(openDraft: { overlay = .editor($0) })
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.paper)

                // Custom tab bar
                MTabBar(tab: $tab)
            }

            // Overlays (full-screen)
            if let ov = overlay {
                Group {
                    switch ov {
                    case .reader(let b):  MReaderView(book: b, onBack: { overlay = nil })
                    case .editor(let d):  MEditorView(draft: d, onBack: { overlay = nil })
                    case .search:         MSearchView(onBack: { overlay = nil })
                    case .settings:       MSettingsView(onBack: { overlay = nil })
                    }
                }
                .transition(.move(edge: .bottom))
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: overlay?.id)
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Tab Bar

struct MTabBar: View {
    @Environment(AppTheme.self) var theme
    @Binding var tab: MTab

    let items: [(MTab, String, String)] = [
        (.library,    "Library",    "books.vertical"),
        (.highlights, "Highlights", "highlighter"),
        (.notes,      "Notes",      "note.text"),
        (.drafts,     "Drafts",     "pencil.line"),
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.0.hashValue) { (t, label, icon) in
                Button {
                    tab = t
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: icon)
                            .font(.system(size: 22))
                        Text(label)
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundColor(tab == t ? theme.accentInk : theme.ink3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 30)
        .background(theme.sidebar)
        .overlay(alignment: .top) { Divider().background(theme.line) }
    }
}
