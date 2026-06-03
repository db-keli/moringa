import SwiftUI

struct SettingsView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    @State private var draftURL   = ""
    @State private var draftToken = ""
    @State private var testing    = false
    @State private var testResult: String?

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

                    // ── Server ─────────────────────────────────────────
                    group("Server") {
                        row(label: "URL", detail: "e.g. http://192.168.1.10:8080") {
                            TextField("http://...", text: $draftURL)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13.5, design: .monospaced))
                                .foregroundColor(theme.ink2)
                                .frame(width: 220)
                                .onAppear { draftURL = store.serverURL }
                        }
                        row(label: "Auth token", detail: "Bearer token from server config") {
                            SecureField("token", text: $draftToken)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13.5, design: .monospaced))
                                .foregroundColor(theme.ink2)
                                .frame(width: 220)
                                .onAppear { draftToken = store.authToken }
                        }
                        HStack {
                            Spacer()
                            if let r = testResult {
                                Text(r).font(.system(size: 12)).foregroundColor(
                                    r.hasPrefix("✓") ? theme.accentInk : .red)
                            }
                            if testing { ProgressView().controlSize(.small) }
                            Button("Test & Save") {
                                store.serverURL = draftURL
                                store.authToken  = draftToken
                                Task { await testConnection() }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.accentInk)
                            .buttonStyle(.plain)
                            .disabled(testing)
                        }
                        .padding(.horizontal, 18).padding(.vertical, 12)
                    }

                    // ── Sync status ────────────────────────────────────
                    group("Sync") {
                        infoRow("Status", store.syncInfo.isConnected ? "Connected" : "Not connected",
                                valueColor: store.syncInfo.isConnected ? theme.accentInk : .red)
                        infoRow("Last synced", store.syncInfo.lastSynced)
                        infoRow("Outbound queue", "\(store.syncInfo.queue) events")
                        HStack {
                            Spacer()
                            Button("Sync now") {
                                Task { await store.syncWithServer() }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.accentInk).buttonStyle(.plain)
                        }
                        .padding(.horizontal, 18).padding(.vertical, 12)
                    }

                    // ── Storage ────────────────────────────────────────
                    group("Storage") {
                        infoRow("Books",      "\(store.books.count)")
                        infoRow("Highlights", "\(store.highlights.count)")
                        infoRow("Notes",      "\(store.notes.count)")
                        infoRow("Drafts",     "\(store.drafts.count)")
                    }

                    // ── Appearance ─────────────────────────────────────
                    group("Appearance") {
                        row(label: "Theme", detail: "") {
                            HStack(spacing: 3) {
                                ForEach(["Light","Dark"], id: \.self) { t in
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
                            .padding(3).background(theme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(theme.line, lineWidth: 1))
                        }
                        row(label: "Accent", detail: "") {
                            HStack(spacing: 9) {
                                ForEach(theme.accentPresets, id: \.self) { hex in
                                    Button { theme.accentHex = hex } label: {
                                        Circle().fill(Color(hex: hex)).frame(width: 26, height: 26)
                                            .overlay(Circle().stroke(
                                                theme.accentHex == hex ? theme.ink : Color.clear, lineWidth: 2))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        row(label: "Reading size", detail: "\(Int(theme.readerSize))px") {
                            Slider(value: $theme.readerSize, in: 16...24, step: 1)
                                .accentColor(theme.accent).frame(width: 160)
                        }
                    }

                    // ── About ──────────────────────────────────────────
                    group("About") {
                        infoRow("moringa", "v0.1.0 · self-hosted reading workspace")
                    }
                }
                .padding(26).padding(.bottom, 40).frame(maxWidth: 660).frame(maxWidth: .infinity)
            }
        }
    }

    private func testConnection() async {
        testing = true
        testResult = nil
        do {
            try await store.api.ping()
            await MainActor.run { testResult = "✓ Connected"; testing = false }
            await store.syncWithServer()
        } catch {
            await MainActor.run { testResult = "✗ \(error.localizedDescription)"; testing = false }
        }
    }

    @ViewBuilder
    private func group<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold)).tracking(0.06).foregroundColor(theme.ink3)
                .padding(.bottom, 10).padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(theme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.line, lineWidth: 1))
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        }.padding(.bottom, 30)
    }

    @ViewBuilder
    private func row<C: View>(label: String, detail: String, @ViewBuilder control: () -> C) -> some View {
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

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String, valueColor: Color? = nil) -> some View {
        HStack {
            Text(label).font(.system(size: 14.5, weight: .medium)).foregroundColor(theme.ink)
            Spacer()
            Text(value).font(.system(size: 13.5)).foregroundColor(valueColor ?? theme.ink2)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .overlay(alignment: .bottom) { Divider().background(theme.line) }
    }
}
