import SwiftUI

struct HighlightsTab: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    @State private var selectedHighlight: Highlight? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Text("Highlights").font(.system(size: 30, weight: .bold)).foregroundColor(theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 8)
                    .background(theme.paper)

                if store.highlights.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "highlighter").font(.system(size: 40)).foregroundColor(theme.ink3)
                        Text("No highlights yet").font(.system(size: 17, weight: .semibold)).foregroundColor(theme.ink)
                        Text("Highlights made while reading appear here.")
                            .font(.system(size: 14)).foregroundColor(theme.ink3).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(store.highlights) { h in
                                MHLCard(highlight: h, book: store.book(id: h.bookId))
                                    .padding(.horizontal, 20).padding(.top, 12)
                                    .onTapGesture { selectedHighlight = h }
                            }
                            Spacer(minLength: 30)
                        }
                    }
                }
            }
            .background(theme.paper)

            // ── Detail overlay ────────────────────────────────────────────────
            if let h = selectedHighlight,
               let live = store.highlights.first(where: { $0.id == h.id }) {
                MHLDetailView(
                    highlight: live,
                    book: store.book(id: live.bookId),
                    onBack: { selectedHighlight = nil },
                    onSaveNote: { store.updateHighlightNote(id: live.id, note: $0 ?? "") },
                    onDelete: { store.deleteHighlight(id: live.id); selectedHighlight = nil }
                )
                .transition(.move(edge: .trailing))
                .zIndex(5)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: selectedHighlight?.id)
    }
}

// MARK: - Highlight Detail View (iOS)

struct MHLDetailView: View {
    @Environment(AppTheme.self) var theme
    let highlight: Highlight
    let book: Book?
    var onBack: () -> Void
    var onSaveNote: (String?) -> Void
    var onDelete: () -> Void

    @State private var noteText: String = ""
    @State private var noteDirty = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 12) {
                    Button {
                        if noteDirty { onSaveNote(noteText.isEmpty ? nil : noteText) }
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.accentInk)
                            .frame(width: 38, height: 38)
                            .background(theme.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(theme.line, lineWidth: 1))
                    }.buttonStyle(.plain)

                    Spacer()

                    if noteDirty {
                        Button("Save") {
                            onSaveNote(noteText.isEmpty ? nil : noteText)
                            noteDirty = false
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.accentInk)
                        .buttonStyle(.plain)
                    }

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundColor(theme.ink3)
                            .frame(width: 38, height: 38)
                            .background(theme.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(theme.line, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.top, 58).padding(.bottom, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Colour chip + meta
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3).fill(highlight.color.color)
                                .frame(width: 10, height: 10)
                            Text(highlight.color.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(highlight.color.color)
                            if let b = book {
                                Text("·").foregroundColor(theme.ink3).font(.system(size: 12))
                                Text(b.title)
                                    .font(.system(size: 12)).foregroundColor(theme.ink3).lineLimit(1)
                            }
                            Spacer()
                            Text(highlight.createdAt.prefix(10))
                                .font(.system(size: 12)).foregroundColor(theme.ink3)
                        }
                        .padding(.bottom, 6)

                        Text(chapterLabel(from: highlight.loc))
                            .font(.system(size: 12)).foregroundColor(theme.ink3)
                            .padding(.bottom, 20)

                        // Highlight text
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 3).fill(highlight.color.color)
                                .frame(width: 3)
                            Text(highlight.text)
                                .font(.system(size: 19)).lineSpacing(8)
                                .foregroundColor(theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 14)
                        }
                        .padding(.bottom, 36)

                        // Note section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Note")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.ink3)

                            ZStack(alignment: .topLeading) {
                                if noteText.isEmpty {
                                    Text("Add a note…")
                                        .font(.system(size: 15))
                                        .foregroundColor(theme.ink3)
                                        .padding(.top, 12).padding(.leading, 16)
                                }
                                TextEditor(text: $noteText)
                                    .font(.system(size: 15))
                                    .foregroundColor(theme.ink)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 140)
                                    .onChange(of: noteText) { noteDirty = true }
                            }
                            .padding(4)
                            .background(theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.line, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            noteText = highlight.note ?? ""
            noteDirty = false
        }
        .confirmationDialog("Delete this highlight?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func chapterLabel(from loc: String) -> String {
        if let data = loc.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let chunk = json["chunk"] as? Int {
            return "Chapter \(chunk + 1)"
        }
        return ""
    }
}

// MARK: - Highlight Card (iOS)

struct MHLCard: View {
    @Environment(AppTheme.self) var theme
    let highlight: Highlight
    let book: Book?

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 14).fill(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.line, lineWidth: 1))
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3).fill(highlight.color.color)
                    .frame(width: 3).padding(.vertical, 14)
                VStack(alignment: .leading, spacing: 0) {
                    Text(highlight.text).font(.system(size: 15.5)).lineSpacing(4)
                        .foregroundColor(theme.ink).padding(.top, 16)
                        .lineLimit(4)
                    HStack(spacing: 6) {
                        if let b = book {
                            Text(b.title).font(.system(size: 12, weight: .semibold)).foregroundColor(theme.ink2)
                            Text("·").foregroundColor(theme.ink3).font(.system(size: 12))
                        }
                        Text(chapterLabel(from: highlight.loc))
                            .font(.system(size: 12)).foregroundColor(theme.ink3)
                        Spacer()
                        Text(highlight.createdAt.prefix(10)).font(.system(size: 12)).foregroundColor(theme.ink3)
                    }.padding(.top, 10).padding(.bottom, highlight.note == nil ? 16 : 10)

                    if let note = highlight.note, !note.isEmpty {
                        Text(note).font(.system(size: 13)).foregroundColor(theme.ink2)
                            .lineLimit(2)
                            .padding(10).background(theme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 8)).padding(.bottom, 14)
                    }
                }.padding(.leading, 12).padding(.trailing, 16)
            }
        }
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
    }

    private func chapterLabel(from loc: String) -> String {
        if let data = loc.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let chunk = json["chunk"] as? Int {
            return "Chapter \(chunk + 1)"
        }
        return ""
    }
}
