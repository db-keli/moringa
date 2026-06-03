import SwiftUI

struct MSettingsView: View {
    @EnvironmentObject var theme: AppTheme
    var onBack: () -> Void

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                            Text("Library")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.accentInk)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Settings")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(theme.ink)

                    Spacer().frame(width: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 58).padding(.bottom, 10)
                .background(theme.paper)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        mGroup("Server & Sync") {
                            mRow(icon: "cloud", label: "Status") {
                                Text("Synced").foregroundColor(theme.accentInk)
                                    .font(.system(size: 14))
                            }
                            mRow(icon: "server.rack", label: "Server") {
                                Text(MockData.sync.server)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(theme.ink3).lineLimit(1)
                            }
                            mRow(icon: "clock", label: "Vector clock") {
                                Text("\(MockData.sync.clockMac)/\(MockData.sync.clockPhone)")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(theme.ink3)
                            }
                        }

                        mGroup("Devices") {
                            ForEach(MockData.sync.devices) { dv in
                                mRow(icon: dv.kind == "mac" ? "desktopcomputer" : "iphone",
                                     label: dv.name) {
                                    Text(dv.last).font(.system(size: 14)).foregroundColor(theme.ink3)
                                }
                            }
                        }

                        mGroup("Appearance") {
                            mRow(icon: theme.isDark ? "moon" : "sun.max", label: "Dark mode") {
                                Toggle("", isOn: $theme.isDark)
                                    .labelsHidden()
                                    .tint(theme.accent)
                            }
                            mRow(icon: "circle.fill", label: "Accent") {
                                HStack(spacing: 9) {
                                    ForEach(theme.accentPresets, id: \.self) { hex in
                                        Button {
                                            theme.accentHex = hex
                                        } label: {
                                            Circle().fill(Color(hex: hex)).frame(width: 24, height: 24)
                                                .overlay(Circle().stroke(
                                                    theme.accentHex == hex ? theme.ink : Color.clear, lineWidth: 2))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            mRow(icon: "textformat.size", label: "Reading size") {
                                Slider(value: $theme.readerSize, in: 16...22, step: 1)
                                    .tint(theme.accent).frame(width: 120)
                            }
                        }

                        mGroup("Storage") {
                            mRow(icon: "books.vertical", label: "Cached books") {
                                Text("\(MockData.sync.cachedBooks) · \(MockData.sync.cacheSize)")
                                    .font(.system(size: 14)).foregroundColor(theme.ink3)
                            }
                        }

                        Text("moringa v0.1.0 · self-hosted")
                            .font(.system(size: 12.5)).foregroundColor(theme.ink3)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 22).padding(.bottom, 30)
                    }
                    .padding(.horizontal, 16).padding(.top, 6)
                }
            }
        }
    }

    @ViewBuilder
    private func mGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold)).tracking(0.02)
                .foregroundColor(theme.ink3)
                .padding(.bottom, 7).padding(.leading, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.line, lineWidth: 1))
        }
        .padding(.bottom, 22)
    }

    @ViewBuilder
    private func mRow<Control: View>(icon: String, label: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(theme.accentSoft)
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(theme.accentInk)
            }
            .frame(width: 28, height: 28)

            Text(label).font(.system(size: 15.5)).foregroundColor(theme.ink).frame(maxWidth: .infinity, alignment: .leading)
            control()
        }
        .padding(.horizontal, 15).padding(.vertical, 11)
        .frame(minHeight: 48)
        .overlay(alignment: .bottom) { Divider().background(theme.line) }
    }
}
