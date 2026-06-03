import SwiftUI

struct SidebarView: View {
    @Environment(AppTheme.self) var theme
    @Binding var screen: AppScreen
    var openSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand
            HStack(spacing: 9) {
                Image("moringa-mark")
                    .resizable().scaledToFit().frame(width: 22, height: 22)
                Text("moringa")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(theme.ink)
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 14)

            // Search
            Button(action: openSearch) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(theme.ink3)
                    Text("Search everything")
                        .font(.system(size: 13.5))
                        .foregroundColor(theme.ink3)
                    Spacer()
                    Text("⌘K")
                        .font(.system(size: 11))
                        .foregroundColor(theme.ink3)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(theme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            navLabel("Library")
            navItem(.library,    "All Books",  "books.vertical")
            navItem(.highlights, "Highlights", "highlighter")
            navItem(.notes,      "Notes",      "note.text")

            navLabel("Writing")
            navItem(.drafts, "Drafts", "pencil.line")

            Spacer()

            // Sync status
            HStack(spacing: 9) {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: theme.accent.opacity(0.4), radius: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Synced")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(theme.ink)
                    Text("just now · 2 devices")
                        .font(.system(size: 11))
                        .foregroundColor(theme.ink3)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(theme.line, lineWidth: 1))
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            navItem(.settings, "Settings", "gearshape")
                .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func navLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.06)
            .foregroundColor(theme.ink3)
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 5)
    }

    @ViewBuilder
    private func navItem(_ s: AppScreen, _ label: String, _ icon: String) -> some View {
        let active = screen == s
        Button {
            screen = s
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 14, weight: active ? .semibold : .medium))
                Spacer()
            }
            .foregroundColor(active ? theme.accentInk : theme.ink2)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(active ? theme.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }
}
