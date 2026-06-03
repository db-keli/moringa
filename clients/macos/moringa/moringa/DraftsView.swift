import SwiftUI

struct DraftsView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    @State private var selectedId: String? = nil

    var selected: Draft? { store.drafts.first(where: { $0.id == selectedId }) ?? store.drafts.first }

    var body: some View {
        HStack(spacing: 0) {
            // Draft list
            VStack(spacing: 0) {
                HStack {
                    Text("Drafts").font(.system(size: 20, weight: .bold)).foregroundColor(theme.ink)
                    Spacer()
                    Button {
                        store.createDraft()
                        selectedId = store.drafts.first?.id
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                            Text("New").font(.system(size: 13.5, weight: .semibold))
                        }
                        .foregroundColor(.white).padding(.horizontal, 12).frame(height: 30)
                        .background(theme.accent).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 18).frame(height: 58)
                .overlay(alignment: .bottom) { Divider().background(theme.line) }

                if store.drafts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "pencil.line").font(.system(size: 32)).foregroundColor(theme.ink3)
                        Text("No drafts").font(.system(size: 14)).foregroundColor(theme.ink3)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(store.drafts) { d in
                                let isActive = (selectedId ?? store.drafts.first?.id) == d.id
                                Button { selectedId = d.id } label: {
                                    DraftRowView(draft: d, isActive: isActive)
                                }.buttonStyle(.plain)
                                Divider().background(theme.line)
                            }
                        }
                    }
                }
            }
            .frame(width: 300)
            .overlay(alignment: .trailing) { Divider().background(theme.line) }

            // Editor
            if let d = selected {
                DraftEditorView(draft: d)
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - Draft Row

struct DraftRowView: View {
    @Environment(AppTheme.self) var theme
    let draft: Draft
    let isActive: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(draft.title)
                .font(.system(size: 14.5, weight: .bold)).foregroundColor(theme.ink).lineLimit(1)
            Text(draft.excerpt)
                .font(.system(size: 12.5)).lineSpacing(2).foregroundColor(theme.ink2).lineLimit(2)
            HStack(spacing: 8) {
                DraftStatusBadge(status: draft.status)
                Text("\(draft.wordCount) words").font(.system(size: 11.5)).foregroundColor(theme.ink3)
                Spacer()
                Text(draft.updatedAt.prefix(10)).font(.system(size: 11.5)).foregroundColor(theme.ink3)
            }.padding(.top, 4)
        }
        .padding(.horizontal, 18).padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isActive ? theme.accentSoft : Color.clear)
    }
}

// MARK: - Draft Editor

struct DraftEditorView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    let draft: Draft
    @State private var title:   String = ""
    @State private var content: String = ""
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                DraftStatusBadge(status: draft.status)
                Text("\(content.split(separator: " ").count) words").font(.system(size: 12.5)).foregroundColor(theme.ink3)
                Text("·").foregroundColor(theme.ink3)
                Text("Edited \(draft.updatedAt.prefix(10))").font(.system(size: 12.5)).foregroundColor(theme.ink3)
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "checkmark").font(.system(size: 12))
                    Text("Saved").font(.system(size: 12.5))
                }.foregroundColor(theme.accentInk)
            }
            .padding(.horizontal, 22).frame(height: 50)
            .overlay(alignment: .bottom) { Divider().background(theme.line) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Title", text: $title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(theme.ink).textFieldStyle(.plain).padding(.bottom, 8)
                    TextEditor(text: $content)
                        .font(.system(size: 17.5)).foregroundColor(theme.ink)
                        .lineSpacing(6).background(theme.reader)
                        .frame(minHeight: 400)
                }
                .frame(maxWidth: 680).padding(.horizontal, 32).padding(.vertical, 44).frame(maxWidth: .infinity)
            }
        }
        .background(theme.reader)
        .onAppear { title = draft.title; content = draft.body }
        .onChange(of: title)   { scheduleSave() }
        .onChange(of: content) { scheduleSave() }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s debounce
            guard !Task.isCancelled else { return }
            store.updateDraft(id: draft.id, title: title, body: content)
        }
    }
}

// MARK: - Status Badge

struct DraftStatusBadge: View {
    @Environment(AppTheme.self) var theme
    let status: DraftStatus
    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.system(size: 10.5, weight: .bold)).tracking(0.04)
            .foregroundColor(status == .published ? theme.accentInk : theme.ink2)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(status == .published ? theme.accentSoft : theme.surface3)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
