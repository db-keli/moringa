import SwiftUI

struct HighlightsView: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    @State private var filter: String = "all"
    @State private var editingNote: Highlight? = nil
    @State private var noteText = ""

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
            // Sub-nav
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

            if store.highlights.isEmpty {
                emptyHighlights
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(shown) { h in
                            HLCard(highlight: h,
                                   book: store.book(id: h.bookId),
                                   onEditNote: { editingNote = h; noteText = h.note ?? "" },
                                   onDelete: { store.deleteHighlight(id: h.id) })
                        }
                    }
                    .padding(26)
                    .frame(maxWidth: 720).frame(maxWidth: .infinity)
                }
            }
        }
        .sheet(item: $editingNote) { h in
            NoteEditorSheet(title: "Note on highlight", text: $noteText) {
                store.updateHighlightNote(id: h.id, note: noteText)
                editingNote = nil
            } onCancel: { editingNote = nil }
        }
    }

    @ViewBuilder private var emptyHighlights: some View {
        VStack(spacing: 12) {
            Image(systemName: "highlighter").font(.system(size: 40)).foregroundColor(theme.ink3)
            Text("No highlights yet").font(.system(size: 17, weight: .semibold)).foregroundColor(theme.ink)
            Text("Highlights you make while reading will appear here.")
                .font(.system(size: 14)).foregroundColor(theme.ink3).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }

    @ViewBuilder private func subLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold)).tracking(0.06).foregroundColor(theme.ink3)
            .padding(.horizontal, 10).padding(.top, 6).padding(.bottom, 4)
    }

    @ViewBuilder private func subItem(id: String, label: String, icon: String, count: Int) -> some View {
        Button { filter = id } label: {
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
        Button { filter = fid } label: {
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
        Button { filter = book.id } label: {
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

// MARK: - Highlight Card

struct HLCard: View {
    @Environment(AppTheme.self) var theme
    let highlight: Highlight
    let book: Book?
    var onEditNote: () -> Void
    var onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12).fill(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.line, lineWidth: 1))
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3).fill(highlight.color.color)
                    .frame(width: 3).padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 0) {
                    Text(highlight.text)
                        .font(.system(size: 16)).lineSpacing(5).foregroundColor(theme.ink)
                        .padding(.top, 18)

                    HStack(spacing: 10) {
                        if let b = book {
                            Text(b.title).font(.system(size: 12.5, weight: .semibold)).foregroundColor(theme.ink2)
                            Text("·").foregroundColor(theme.ink3)
                        }
                        if !highlight.loc.isEmpty {
                            Text(highlight.loc).font(.system(size: 12.5)).foregroundColor(theme.ink3)
                        }
                        Spacer()
                        Button("Add note", action: onEditNote)
                            .font(.system(size: 12)).foregroundColor(theme.accentInk).buttonStyle(.plain)
                        Button { onDelete() } label: {
                            Image(systemName: "trash").font(.system(size: 12))
                        }.buttonStyle(.plain).foregroundColor(theme.ink3)
                    }
                    .padding(.top, 13).padding(.bottom, highlight.note == nil ? 18 : 11)

                    if let note = highlight.note, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 13.5)).lineSpacing(3).foregroundColor(theme.ink2)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.surface2).clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.bottom, 18)
                    }
                }
                .padding(.leading, 14).padding(.trailing, 20)
            }
        }
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Note Editor Sheet

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
