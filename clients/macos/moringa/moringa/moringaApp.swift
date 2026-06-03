import SwiftUI

@main
struct moringaApp: App {
    @StateObject private var theme = AppTheme()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(theme)
                .preferredColorScheme(theme.isDark ? .dark : .light)
        }
        .defaultSize(width: 1100, height: 700)
        .windowResizability(.contentMinSize)
    }
}
