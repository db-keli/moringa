import SwiftUI

struct NotesTab: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    @State private var showNew = false
    @State private var newTitle = ""
    @State private var newBody  = ""

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Text("Notes").font(.system(size: 30, weight: .bold)).foregroundColor(theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 8)
                    .background(theme.paper)

                if store.notes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "note.text").font(.system(size: 40)).foregroundColor(theme.ink3)
                        Text("No notes yet").font(.system(size: 17, weight: .semibold)).foregroundColor(theme.ink)
                        Text("Tap + to capture an idea.").font(.system(size: 14)).foregroundColor(theme.ink3)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(store.notes) { n in
                                MNoteCard(note: n).padding(.horizontal, 20)
                            }
                            Spacer(minLength: 30)
                        }.padding(.top, 12)
                    }
                }
            }

            Button { newTitle = ""; newBody = ""; showNew = true } label: {
                Image(systemName: "plus").font(.system(size: 22, weight: .semibold)).foregroundColor(.white)
                    .frame(width: 52, height: 52).background(theme.accent).clipShape(Circle())
                    .shadow(color: theme.accent.opacity(0.45), radius: 12, x: 0, y: 4)
            }.buttonStyle(.plain).padding(.trailing, 18).padding(.bottom, 10)
        }
        .sheet(isPresented: $showNew) {
            MNoteSheet(title: $newTitle, body: $newBody,
                onSave: { guard !newTitle.isEmpty else { return }
                    store.createNote(title: newTitle, body: newBody); showNew = false },
                onCancel: { showNew = false })
        }
    }
}

struct MNoteCard: View {
    @Environment(AppTheme.self) var theme
    let note: Note
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title).font(.system(size: 15.5, weight: .bold)).foregroundColor(theme.ink)
            Text(note.body).font(.system(size: 13.5)).lineSpacing(3).foregroundColor(theme.ink2).lineLimit(3)
            HStack {
                Text("Idea").font(.system(size: 11.5, weight: .semibold)).foregroundColor(theme.ink2)
                Spacer()
                Text(note.createdAt.prefix(10)).font(.system(size: 11.5)).foregroundColor(theme.ink3)
            }.padding(.top, 4)
        }
        .padding(16).background(theme.surface).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

struct MNoteSheet: View {
    @Environment(AppTheme.self) var theme
    @Binding var title: String
    @Binding var body: String
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                TextField("Title", text: $title)
                    .font(.system(size: 22, weight: .bold)).textFieldStyle(.plain)
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
                TextEditor(text: $body)
                    .font(.system(size: 16)).foregroundColor(theme.ink)
                    .padding(.horizontal, 16)
            }
            .background(theme.surface)
            .navigationTitle("New note").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave).fontWeight(.semibold)
                }
            }
        }
    }
}
