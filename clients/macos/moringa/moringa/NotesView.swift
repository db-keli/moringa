import SwiftUI

struct NotesView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    @State private var editingNote: Note? = nil
    @State private var showNewNote = false
    @State private var newTitle = ""
    @State private var newBody  = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notes").font(.system(size: 20, weight: .bold)).foregroundColor(theme.ink)
                Spacer()
                Button {
                    newTitle = ""; newBody = ""; showNewNote = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                        Text("New note").font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundColor(theme.ink).padding(.horizontal, 14).frame(height: 34)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(theme.line, lineWidth: 1))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 26).frame(height: 58)
            .overlay(alignment: .bottom) { Divider().background(theme.line) }

            if store.notes.isEmpty {
                emptyNotes
            } else {
                ScrollView {
                    let cols = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
                    LazyVGrid(columns: cols, spacing: 16) {
                        ForEach(store.notes) { note in
                            NoteCard(note: note, book: note.bookId.flatMap { store.book(id: $0) })
                                .onTapGesture { editingNote = note }
                        }
                    }
                    .padding(26)
                }
            }
        }
        // New note sheet
        .sheet(isPresented: $showNewNote) {
            NoteWriteSheet(title: $newTitle, body: $newBody,
                onSave: {
                    guard !newTitle.isEmpty else { return }
                    store.createNote(title: newTitle, body: newBody)
                    showNewNote = false
                },
                onCancel: { showNewNote = false })
        }
        // Edit note sheet
        .sheet(item: $editingNote) { note in
            NoteEditSheet(note: note,
                onSave: { title, body in
                    store.updateNote(id: note.id, title: title, body: body)
                    editingNote = nil
                },
                onDelete: {
                    store.deleteNote(id: note.id)
                    editingNote = nil
                },
                onCancel: { editingNote = nil })
        }
    }

    @ViewBuilder private var emptyNotes: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text").font(.system(size: 40)).foregroundColor(theme.ink3)
            Text("No notes yet").font(.system(size: 17, weight: .semibold)).foregroundColor(theme.ink)
            Text("Capture ideas and thoughts while you read.")
                .font(.system(size: 14)).foregroundColor(theme.ink3).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }
}

// MARK: - Note Card

struct NoteCard: View {
    @Environment(AppTheme.self) var theme
    let note: Note
    let book: Book?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.title).font(.system(size: 15, weight: .bold)).foregroundColor(theme.ink).lineLimit(2)
            Text(note.body).font(.system(size: 13)).lineSpacing(3).foregroundColor(theme.ink2).lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                if let b = book {
                    HStack(spacing: 5) {
                        Image(systemName: "book").font(.system(size: 11))
                        Text(b.title).lineLimit(1)
                    }
                    .font(.system(size: 11.5, weight: .semibold)).foregroundColor(theme.accentInk)
                    .padding(.horizontal, 8).padding(.vertical, 2).background(theme.accentSoft).clipShape(Capsule())
                } else {
                    Text("Idea").font(.system(size: 11.5, weight: .semibold)).foregroundColor(theme.ink2)
                        .padding(.horizontal, 8).padding(.vertical, 2).background(theme.surface3).clipShape(Capsule())
                }
                Spacer()
                Text(note.createdAt.prefix(10)).font(.system(size: 11.5)).foregroundColor(theme.ink3)
            }
        }
        .padding(18).frame(minHeight: 150, alignment: .topLeading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
    }
}

// MARK: - New Note Sheet

struct NoteWriteSheet: View {
    @Environment(AppTheme.self) var theme
    @Binding var title: String
    @Binding var body: String
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("New note").font(.system(size: 16, weight: .semibold)).foregroundColor(theme.ink)
                Spacer()
                Button("Cancel", action: onCancel).foregroundColor(theme.ink2).buttonStyle(.plain)
                Button("Save", action: onSave).foregroundColor(theme.accentInk).fontWeight(.semibold).buttonStyle(.plain)
            }
            .padding().overlay(alignment: .bottom) { Divider().background(theme.line) }

            TextField("Title", text: $title)
                .font(.system(size: 18, weight: .semibold)).textFieldStyle(.plain)
                .padding(.horizontal).padding(.top, 14)
            TextEditor(text: $body)
                .font(.system(size: 14)).foregroundColor(theme.ink).background(theme.surface)
                .padding(.horizontal).padding(.top, 8)
        }
        .frame(width: 500, height: 320).background(theme.surface)
    }
}

// MARK: - Edit Note Sheet

struct NoteEditSheet: View {
    @Environment(AppTheme.self) var theme
    let note: Note
    @State private var title: String
    @State private var body: String
    var onSave: (String, String) -> Void
    var onDelete: () -> Void
    var onCancel: () -> Void

    init(note: Note, onSave: @escaping (String, String) -> Void,
         onDelete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.note = note
        _title = State(initialValue: note.title)
        _body  = State(initialValue: note.body)
        self.onSave   = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { onDelete() } label: {
                    Image(systemName: "trash").foregroundColor(.red)
                }.buttonStyle(.plain)
                Spacer()
                Button("Cancel", action: onCancel).foregroundColor(theme.ink2).buttonStyle(.plain)
                Button("Save") { onSave(title, body) }
                    .foregroundColor(theme.accentInk).fontWeight(.semibold).buttonStyle(.plain)
            }
            .padding().overlay(alignment: .bottom) { Divider().background(theme.line) }

            TextField("Title", text: $title)
                .font(.system(size: 18, weight: .semibold)).textFieldStyle(.plain)
                .padding(.horizontal).padding(.top, 14)
            TextEditor(text: $body)
                .font(.system(size: 14)).foregroundColor(theme.ink).background(theme.surface)
                .padding(.horizontal).padding(.top, 8)
        }
        .frame(width: 500, height: 360).background(theme.surface)
    }
}
