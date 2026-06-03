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
    }
}
