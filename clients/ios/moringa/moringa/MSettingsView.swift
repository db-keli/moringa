import SwiftUI

struct MSettingsView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    var onBack: () -> Void

    @State private var draftURL   = ""
    @State private var draftToken = ""
    @State private var testing    = false
    @State private var testResult: String?

    var body: some View {
        @Bindable var theme = theme
        return ZStack {
            theme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                            Text("Library")
                        }.font(.system(size: 15, weight: .semibold)).foregroundColor(theme.accentInk)
                    }.buttonStyle(.plain)
                    Spacer()
                    Text("Settings").font(.system(size: 17, weight: .bold)).foregroundColor(theme.ink)
                    Spacer().frame(width: 80)
                }
                .padding(.horizontal, 16).padding(.top, 58).padding(.bottom, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        mGroup("Server") {
                            mTextRow(icon: "link", label: "URL", placeholder: "http://...", text: $draftURL)
                                .onAppear { draftURL = store.serverURL }
                            mTextRow(icon: "key", label: "Token", placeholder: "auth token", text: $draftToken, secure: true)
                                .onAppear { draftToken = store.authToken }
                            mActionRow(icon: "arrow.triangle.2.circlepath", label: "Test & Save") {
                                store.serverURL = draftURL
                                store.authToken  = draftToken
                                Task { await testConn() }
                            }
                            if let r = testResult {
                                Text(r).font(.system(size: 13))
                                    .foregroundColor(r.hasPrefix("✓") ? theme.accentInk : .red)
                                    .padding(.horizontal, 15).padding(.bottom, 10)
                            }
                        }

                        mGroup("Sync") {
                            mInfoRow(icon: "cloud", label: "Status",
                                     value: store.syncInfo.isConnected ? "Connected" : "Not connected",
                                     valueColor: store.syncInfo.isConnected ? theme.accentInk : .red)
                            mInfoRow(icon: "clock", label: "Last synced", value: store.syncInfo.lastSynced)
                            mInfoRow(icon: "tray.and.arrow.up", label: "Queue", value: "\(store.syncInfo.queue) events")
                            mActionRow(icon: "arrow.clockwise", label: "Sync now") {
                                Task { await store.syncWithServer() }
                            }
                        }

                        mGroup("Storage") {
                            mInfoRow(icon: "books.vertical", label: "Books",      value: "\(store.books.count)")
                            mInfoRow(icon: "highlighter",    label: "Highlights", value: "\(store.highlights.count)")
                            mInfoRow(icon: "note.text",      label: "Notes",      value: "\(store.notes.count)")
                            mInfoRow(icon: "pencil.line",    label: "Drafts",     value: "\(store.drafts.count)")
                        }

                        mGroup("Appearance") {
                            mRow(icon: theme.isDark ? "moon" : "sun.max", label: "Dark mode") {
                                Toggle("", isOn: $theme.isDark).labelsHidden().tint(theme.accent)
                            }
                            mRow(icon: "circle.fill", label: "Accent") {
                                HStack(spacing: 9) {
                                    ForEach(theme.accentPresets, id: \.self) { hex in
                                        Button { theme.accentHex = hex } label: {
                                            Circle().fill(Color(hex: hex)).frame(width: 24, height: 24)
                                                .overlay(Circle().stroke(theme.accentHex == hex ? theme.ink : Color.clear, lineWidth: 2))
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                            mRow(icon: "textformat.size", label: "Reading size") {
                                Slider(value: $theme.readerSize, in: 16...22, step: 1)
                                    .tint(theme.accent).frame(width: 120)
                            }
                        }

                        Text("moringa v0.1.0 · self-hosted")
                            .font(.system(size: 12.5)).foregroundColor(theme.ink3)
                            .frame(maxWidth: .infinity, alignment: .center).padding(.top, 22).padding(.bottom, 30)
                    }
                    .padding(.horizontal, 16).padding(.top, 6)
                }
            }
        }
    }

    private func testConn() async {
        testing = true; testResult = nil
        do {
            try await store.api.ping()
            await MainActor.run { testResult = "✓ Connected"; testing = false }
            await store.syncWithServer()
        } catch {
            await MainActor.run { testResult = "✗ \(error.localizedDescription)"; testing = false }
        }
    }

    @ViewBuilder private func mGroup<C: View>(_ t: String, @ViewBuilder c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(t.uppercased()).font(.system(size: 12, weight: .semibold)).tracking(0.02)
                .foregroundColor(theme.ink3).padding(.bottom, 7).padding(.leading, 8)
            VStack(spacing: 0) { c() }
                .background(theme.surface).clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.line, lineWidth: 1))
        }.padding(.bottom, 22)
    }

    @ViewBuilder private func mRow<C: View>(icon: String, label: String, @ViewBuilder c: () -> C) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(theme.accentSoft)
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(theme.accentInk)
            }.frame(width: 28, height: 28)
            Text(label).font(.system(size: 15.5)).foregroundColor(theme.ink).frame(maxWidth: .infinity, alignment: .leading)
            c()
        }.padding(.horizontal, 15).padding(.vertical, 11).frame(minHeight: 48)
            .overlay(alignment: .bottom) { Divider().background(theme.line) }
    }

    @ViewBuilder private func mInfoRow(icon: String, label: String, value: String, valueColor: Color? = nil) -> some View {
        mRow(icon: icon, label: label) {
            Text(value).font(.system(size: 14)).foregroundColor(valueColor ?? theme.ink3)
        }
    }

    @ViewBuilder private func mTextRow(icon: String, label: String, placeholder: String, text: Binding<String>, secure: Bool = false) -> some View {
        mRow(icon: icon, label: label) {
            Group {
                if secure { SecureField(placeholder, text: text) }
                else { TextField(placeholder, text: text) }
            }
            .font(.system(size: 13, design: .monospaced)).foregroundColor(theme.ink2)
            .textFieldStyle(.plain).multilineTextAlignment(.trailing).frame(width: 160)
        }
    }

    @ViewBuilder private func mActionRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        mRow(icon: icon, label: label) {
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(theme.ink3)
        }
        .contentShape(Rectangle()).onTapGesture { action() }
    }
}
