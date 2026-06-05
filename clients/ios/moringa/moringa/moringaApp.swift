import SwiftUI

@main
struct moringaApp: App {
    @State private var theme = AppTheme()
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(theme)
                .environment(store)
                .preferredColorScheme(theme.isDark ? .dark : .light)
                .task { await store.syncWithServer() }
        }
    }
}
