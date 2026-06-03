import SwiftUI

struct MEditorView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    let draft: Draft
    var onBack: () -> Void

    @State private var title: String = ""
    @State private var body:  String = ""
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            theme.reader.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.ink2).frame(width: 38, height: 38)
                            .background(theme.surface).clipShape(Circle())
                            .overlay(Circle().stroke(theme.line, lineWidth: 1))
                    }.buttonStyle(.plain)
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark").font(.system(size: 12))
                        Text("Saved").font(.system(size: 12.5))
                    }.foregroundColor(theme.accentInk)
                }
                .padding(.horizontal, 16).padding(.top, 58).padding(.bottom, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Title", text: $title)
                            .font(.system(size: 26, weight: .bold)).foregroundColor(theme.ink)
                            .textFieldStyle(.plain).frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(body.split(separator:" ").count) words · \(draft.updatedAt.prefix(10))")
                            .font(.system(size: 12)).foregroundColor(theme.ink3)
                            .padding(.top, 6).padding(.bottom, 14)
                        TextEditor(text: $body)
                            .font(.system(size: 16.5)).foregroundColor(theme.ink)
                            .lineSpacing(5).background(theme.reader).frame(minHeight: 300)
                    }
                    .padding(.horizontal, 24).padding(.bottom, 80)
                }
            }
        }
        .onAppear { title = draft.title; body = draft.body }
        .onChange(of: title) { scheduleSave() }
        .onChange(of: body)  { scheduleSave() }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            store.updateDraft(id: draft.id, title: title, body: body)
        }
    }
}
