import SwiftUI

struct HighlightsView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    @State private var filter: String = "all"
    @State private var selectedHighlight: Highlight? = nil

    var byBook: [String: [Highlight]] {
        Dictionary(grouping: store.highlights, by: \.bookId)
    }

    var shown: [Highlight] {
        if filter == "all" { return store.highlights }
        if filter.hasPrefix("c:") {
            let c = String(filter.dropFirst(2))
            return store.highlights.filter { $0.color.rawValue == c }
        }
        return store.highlights.filter { $0.bookId == filter }
    }

    var body: some View {
        HStack(spacing: 0) {
            // ── Sub-nav ───────────────────────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    subLabel("Collections")
                    subItem(id: "all", label: "All highlights",
                            icon: "highlighter", count: store.highlights.count)

                    subLabel("By colour")
                    ForEach(HLColor.allCases, id: \.self) { c in
                        subColorItem(c)
                    }

                    if !byBook.isEmpty {
                        subLabel("By book")
                        ForEach(byBook.keys.sorted(), id: \.self) { bid in
                            if let book = store.book(id: bid) {
                                subBookItem(book: book, count: byBook[bid]?.count ?? 0)
                            }
                        }
                    }
                }
                .padding(10)
            }
            .frame(width: 232)
            .overlay(alignment: .trailing) { Divider().background(theme.line) }

            // ── Main content ──────────────────────────────────────────────────
            if store.highlights.isEmpty {
                emptyHighlights
            } else if let h = selectedHighlight, let live = store.highlights.first(where: { $0.id == h.id }) {
                // Detail view
                HLDetailView(highlight: live,
                             book: store.book(id: live.bookId),
                             onBack: { selectedHighlight = nil },
                             onSaveNote: { store.updateHighlightNote(id: live.id, note: $0 ?? "") },
                             onDelete: { store.deleteHighlight(id: live.id); selectedHighlight = nil })
            } else {
                // Card list
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(shown) { h in
                            HLCard(highlight: h,
                                   book: store.book(id: h.bookId),
                                   isSelected: selectedHighlight?.id == h.id)
                            .onTapGesture { selectedHighlight = h }
                        }
                    }
                    .padding(26)
                    .frame(maxWidth: 720).frame(maxWidth: .infinity)
                }
            }
        }
    }

    // ── Empty state ───────────────────────────────────────────────────────────

    @ViewBuilder private var emptyHighlights: some View {
        VStack(spacing: 12) {
            Image(systemName: "highlighter").font(.system(size: 40)).foregroundColor(theme.ink3)
            Text("No highlights yet").font(.system(size: 17, weight: .semibold)).foregroundColor(theme.ink)
            Text("Highlights you make while reading will appear here.")
                .font(.system(size: 14)).foregroundColor(theme.ink3).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }

    // ── Sub-nav helpers ───────────────────────────────────────────────────────

    @ViewBuilder private func subLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold)).tracking(0.06).foregroundColor(theme.ink3)
            .padding(.horizontal, 10).padding(.top, 6).padding(.bottom, 4)
    }

    @ViewBuilder private func subItem(id: String, label: String, icon: String, count: Int) -> some View {
        Button { filter = id; selectedHighlight = nil } label: {
            HStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 13)).frame(width: 16)
                Text(label).font(.system(size: 13.5, weight: filter == id ? .semibold : .medium))
                Spacer()
                Text("\(count)").font(.system(size: 12)).foregroundColor(theme.ink3)
            }
            .foregroundColor(filter == id ? theme.ink : theme.ink2)
            .padding(.horizontal, 10).frame(height: 32)
            .background(filter == id ? theme.surface2 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }

    @ViewBuilder private func subColorItem(_ c: HLColor) -> some View {
        let fid = "c:\(c.rawValue)"
        Button { filter = fid; selectedHighlight = nil } label: {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 2).fill(c.color).frame(width: 9, height: 9)
                Text(c.label).font(.system(size: 13.5, weight: filter == fid ? .semibold : .medium))
                Spacer()
                Text("\(store.highlights.filter { $0.color == c }.count)")
                    .font(.system(size: 12)).foregroundColor(theme.ink3)
            }
            .foregroundColor(filter == fid ? theme.ink : theme.ink2)
            .padding(.horizontal, 10).frame(height: 32)
            .background(filter == fid ? theme.surface2 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }

    @ViewBuilder private func subBookItem(book: Book, count: Int) -> some View {
        Button { filter = book.id; selectedHighlight = nil } label: {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 2).fill(book.color).frame(width: 9, height: 9)
                Text(book.title).font(.system(size: 13.5, weight: filter == book.id ? .semibold : .medium)).lineLimit(1)
                Spacer()
                Text("\(count)").font(.system(size: 12)).foregroundColor(theme.ink3)
            }
            .foregroundColor(filter == book.id ? theme.ink : theme.ink2)
            .padding(.horizontal, 10).frame(height: 32)
            .background(filter == book.id ? theme.surface2 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
}

// MARK: - Highlight Detail View (macOS)

struct HLDetailView: View {
    @Environment(AppTheme.self) var theme
    let highlight: Highlight
    let book: Book?
    var onBack: () -> Void
    var onSaveNote: (String?) -> Void
    var onDelete: () -> Void

    @State private var noteText: String = ""
    @State private var noteDirty = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            ZStack {
                // Save + Delete — centred with the content column
                HStack(spacing: 16) {
                    Spacer()
                    if noteDirty {
                        Button("Save") {
                            onSaveNote(noteText.isEmpty ? nil : noteText)
                            noteDirty = false
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.accentInk)
                        .buttonStyle(.plain)
                    }
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash").font(.system(size: 13))
                            .foregroundColor(theme.ink3)
                    }
                    .buttonStyle(.plain)
                    .help("Delete highlight")
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: 720).frame(maxWidth: .infinity)

                // Back button — pinned to the far left regardless of content width
                HStack {
                    Button {
                        if noteDirty { onSaveNote(noteText.isEmpty ? nil : noteText) }
                        onBack()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                            Text("Highlights").font(.system(size: 13))
                        }
                        .foregroundColor(theme.accentInk)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 26)
            }
            .frame(height: 52)
            .overlay(alignment: .bottom) { Divider().background(theme.line) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Colour chip + book info
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3).fill(highlight.color.color)
                            .frame(width: 10, height: 10)
                        Text(highlight.color.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(highlight.color.color)
                        if let b = book {
                            Text("·").foregroundColor(theme.ink3)
                            Text(b.title)
                                .font(.system(size: 12))
                                .foregroundColor(theme.ink3)
                                .lineLimit(1)
                        }
                        Text("·").foregroundColor(theme.ink3)
                        Text(chapterLabel(from: highlight.loc))
                            .font(.system(size: 12)).foregroundColor(theme.ink3)
                        Spacer()
                        Text(highlight.createdAt.prefix(10))
                            .font(.system(size: 12)).foregroundColor(theme.ink3)
                    }
                    .padding(.bottom, 18)

                    // Highlight text
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 3).fill(highlight.color.color)
                            .frame(width: 3)
                        Text(highlight.text)
                            .font(.system(size: 18)).lineSpacing(7)
                            .foregroundColor(theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 16)
                    }
                    .padding(.bottom, 32)

                    // Note section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Note")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.ink3)

                        TextEditor(text: $noteText)
                            .font(.system(size: 14))
                            .foregroundColor(theme.ink)
                            .scrollContentBackground(.hidden)
                            .background(theme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(theme.line, lineWidth: 1)
                            )
                            .frame(minHeight: 120)
                            .onChange(of: noteText) { noteDirty = true }

                        if !noteDirty {
                            Text("Click to edit note")
                                .font(.system(size: 12)).foregroundColor(theme.ink3)
                                .allowsHitTesting(false)
                                .opacity(noteText.isEmpty ? 1 : 0)
                        }
                    }
                }
                .padding(26)
                .frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            noteText = highlight.note ?? ""
            noteDirty = false
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

// MARK: - Highlight Card (macOS)

struct HLCard: View {
    @Environment(AppTheme.self) var theme
    let highlight: Highlight
    let book: Book?
    var isSelected: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? theme.surface2 : theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? highlight.color.color.opacity(0.5) : theme.line, lineWidth: isSelected ? 1.5 : 1)
                )
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3).fill(highlight.color.color)
                    .frame(width: 3).padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 0) {
                    Text(highlight.text)
                        .font(.system(size: 15.5)).lineSpacing(4).foregroundColor(theme.ink)
                        .padding(.top, 16)
                        .lineLimit(4)

                    HStack(spacing: 8) {
                        if let b = book {
                            Text(b.title).font(.system(size: 12, weight: .semibold)).foregroundColor(theme.ink2)
                            Text("·").foregroundColor(theme.ink3)
                        }
                        Text(chapterLabel(from: highlight.loc))
                            .font(.system(size: 12)).foregroundColor(theme.ink3)
                        Spacer()
                        Text(highlight.createdAt.prefix(10))
                            .font(.system(size: 12)).foregroundColor(theme.ink3)
                    }
                    .padding(.top, 10).padding(.bottom, highlight.note == nil ? 16 : 10)

                    if let note = highlight.note, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 13)).lineSpacing(3).foregroundColor(theme.ink2)
                            .lineLimit(2)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.surface2).clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.bottom, 16)
                    }
                }
                .padding(.leading, 14).padding(.trailing, 20)
            }
        }
        .shadow(color: .black.opacity(isSelected ? 0.07 : 0.04), radius: isSelected ? 4 : 2, x: 0, y: 1)
        .contentShape(Rectangle())
        .cursor(.pointingHand)
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

// MARK: - Note Editor Sheet (kept for other uses)

struct NoteEditorSheet: View {
    @Environment(AppTheme.self) var theme
    let title: String
    @Binding var text: String
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(theme.ink)
                Spacer()
                Button("Cancel", action: onCancel).foregroundColor(theme.ink2).buttonStyle(.plain)
                Button("Save", action: onSave).foregroundColor(theme.accentInk).fontWeight(.semibold).buttonStyle(.plain)
            }
            .padding()
            .overlay(alignment: .bottom) { Divider().background(theme.line) }

            TextEditor(text: $text)
                .font(.system(size: 14))
                .foregroundColor(theme.ink)
                .background(theme.surface)
                .padding()
        }
        .frame(width: 420, height: 240)
        .background(theme.surface)
    }
}

// MARK: - Cursor helper (macOS only)

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}
