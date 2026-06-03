import SwiftUI

@main
struct moringaApp: App {
    @State private var theme = AppTheme()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(theme)
                .preferredColorScheme(theme.isDark ? .dark : .light)
        }
        .defaultSize(width: 1100, height: 700)
        .windowResizability(.contentMinSize)
    }
}
