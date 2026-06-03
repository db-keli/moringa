import SwiftUI

enum AppScreen: String, Hashable {
    case library, highlights, notes, drafts, search, settings
}

struct ContentView: View {
    @EnvironmentObject var theme: AppTheme
    @State private var screen: AppScreen = .library
    @State private var openedBook: Book? = nil

    var body: some View {
        ZStack {
            // Main layout
            HStack(spacing: 0) {
                SidebarView(screen: $screen, openSearch: { screen = .search })
                    .frame(width: 248)
                    .background(theme.sidebar)

                Divider().background(theme.line)

                Group {
                    switch screen {
                    case .library:    LibraryView(openBook: { openedBook = $0 })
                    case .highlights: HighlightsView()
                    case .notes:      NotesView()
                    case .drafts:     DraftsView()
                    case .search:     SearchView()
                    case .settings:   SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.paper)
            }
            .background(theme.paper)

            // Reader full-screen overlay
            if let book = openedBook {
                ReaderView(book: book, onBack: {
                    withAnimation(.easeInOut(duration: 0.22)) { openedBook = nil }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: openedBook?.id)
        .frame(minWidth: 860, minHeight: 540)
    }
}
