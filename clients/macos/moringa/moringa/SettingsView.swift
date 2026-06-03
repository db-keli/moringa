import SwiftUI

struct SettingsView: View {
    @Environment(AppTheme.self) var theme

    var body: some View {
        @Bindable var theme = theme
        return VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.system(size: 20, weight: .bold)).foregroundColor(theme.ink)
                Spacer()
            }
            .padding(.horizontal, 26).frame(height: 58)
            .overlay(alignment: .bottom) { Divider().background(theme.line) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Server & Sync
                    settingGroup("Server & Sync") {
                        settingRow(label: "Server", detail: MockData.sync.region, value: MockData.sync.server, mono: true)
                        settingRow(label: "Status", detail: "Local-first · changes sync in the background") {
                            HStack(spacing: 7) {
                                Circle().fill(theme.accent).frame(width: 8, height: 8)
                                    .shadow(color: theme.accent.opacity(0.4), radius: 3)
                                Text("Synced · \(MockData.sync.lastSynced)")
                                    .font(.system(size: 13.5)).foregroundColor(theme.accentInk)
                            }
                        }
                        settingRow(label: "Vector clock", detail: "Per-device sync position",
                                   value: "{ mac: \(MockData.sync.clockMac), phone: \(MockData.sync.clockPhone) }", mono: true)
                        settingRow(label: "Outbound queue", detail: "Unsynced events waiting to send",
                                   value: "\(MockData.sync.queue) events")
                    }

                    // Devices
                    settingGroup("Devices") {
                        ForEach(MockData.sync.devices) { dv in
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9).fill(theme.accentSoft)
                                    Image(systemName: dv.kind == "mac" ? "desktopcomputer" : "iphone")
                                        .font(.system(size: 15)).foregroundColor(theme.accentInk)
                                }
                                .frame(width: 34, height: 34)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(dv.name).font(.system(size: 14.5, weight: .medium)).foregroundColor(theme.ink)
                                        if dv.isCurrent {
                                            Text("· this device").font(.system(size: 13)).foregroundColor(theme.ink3)
                                        }
                                    }
                                    Text("Last seen \(dv.last)").font(.system(size: 12.5)).foregroundColor(theme.ink3)
                                }
                                Spacer()
                                Text("seq \(dv.seq)")
                                    .font(.system(size: 13.5, design: .monospaced)).foregroundColor(theme.ink2)
                            }
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .overlay(alignment: .bottom) { Divider().background(theme.line) }
                        }
                    }

                    // Appearance
                    settingGroup("Appearance") {
                        settingRow(label: "Theme", detail: "Warm paper or green-tinted dark") {
                            HStack(spacing: 3) {
                                ForEach(["Light", "Dark"], id: \.self) { t in
                                    let on = (t == "Dark") == theme.isDark
                                    Button(t) { theme.isDark = (t == "Dark") }
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(on ? theme.ink : theme.ink2)
                                        .frame(height: 28).padding(.horizontal, 12)
                                        .background(on ? theme.surface : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(3)
                            .background(theme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(theme.line, lineWidth: 1))
                        }

                        settingRow(label: "Accent", detail: "Moringa green") {
                            HStack(spacing: 9) {
                                ForEach(theme.accentPresets, id: \.self) { hex in
                                    Button {
                                        theme.accentHex = hex
                                    } label: {
                                        Circle().fill(Color(hex: hex)).frame(width: 26, height: 26)
                                            .overlay(Circle().stroke(
                                                theme.accentHex == hex ? theme.ink : Color.clear, lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        settingRow(label: "Reading size", detail: "\(Int(theme.readerSize))px") {
                            Slider(value: $theme.readerSize, in: 16...24, step: 1)
                                .accentColor(theme.accent).frame(width: 160)
                        }
                    }

                    // Storage
                    settingGroup("Storage") {
                        settingRow(label: "Cached books", detail: "Downloaded for offline reading",
                                   value: "\(MockData.sync.cachedBooks) · \(MockData.sync.cacheSize)")
                        settingRow(label: "Library data", detail: "Highlights & notes in local SQLite",
                                   value: "\(MockData.highlights.count) highlights · \(MockData.notes.count) notes")
                    }

                    // About
                    settingGroup("About") {
                        settingRow(label: "moringa", detail: "Self-hosted reading & writing workspace",
                                   value: "v0.1.0", mono: true)
                    }
                }
                .padding(26).padding(.bottom, 40)
                .frame(maxWidth: 660)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func settingGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold)).tracking(0.06)
                .foregroundColor(theme.ink3)
                .padding(.bottom, 10).padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        }
        .padding(.bottom, 30)
    }

    @ViewBuilder
    private func settingRow(label: String, detail: String, value: String = "", mono: Bool = false) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 14.5, weight: .medium)).foregroundColor(theme.ink)
                Text(detail).font(.system(size: 12.5)).foregroundColor(theme.ink3)
            }
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(mono ? .system(size: 13.5, design: .monospaced) : .system(size: 13.5))
                    .foregroundColor(theme.ink2)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .overlay(alignment: .bottom) { Divider().background(theme.line) }
    }

    @ViewBuilder
    private func settingRow<Control: View>(label: String, detail: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 14.5, weight: .medium)).foregroundColor(theme.ink)
                if !detail.isEmpty {
                    Text(detail).font(.system(size: 12.5)).foregroundColor(theme.ink3)
                }
            }
            Spacer()
            control()
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .overlay(alignment: .bottom) { Divider().background(theme.line) }
    }
}
