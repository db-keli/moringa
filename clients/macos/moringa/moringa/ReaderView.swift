import SwiftUI

struct ReaderView: View {
    @EnvironmentObject var theme: AppTheme
    let book: Book
    var onBack: () -> Void

    @State private var highlights: [Int: HLColor] = [1: .yellow, 3: .green]
    @State private var selectedPara: Int? = nil

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 8) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(IconBtnStyle(ink2Color: theme.ink2, surface2Color: theme.surface2))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(book.title).font(.system(size: 13.5, weight: .semibold)).foregroundColor(theme.ink)
                        Text(book.author).font(.system(size: 12)).foregroundColor(theme.ink3)
                    }

                    Spacer()
                    Button { } label: { Image(systemName: "list.bullet").font(.system(size: 14)) }
                        .buttonStyle(IconBtnStyle(ink2Color: theme.ink2, surface2Color: theme.surface2))
                    Button { } label: { Image(systemName: "textformat.size").font(.system(size: 14)) }
                        .buttonStyle(IconBtnStyle(ink2Color: theme.ink2, surface2Color: theme.surface2))
                    Button { } label: { Image(systemName: "highlighter").font(.system(size: 14)) }
                        .buttonStyle(IconBtnStyle(ink2Color: theme.ink2, surface2Color: theme.surface2))
                }
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(theme.reader)
                .overlay(alignment: .bottom) { Divider().background(theme.line) }

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(MockData.readerParas[0].hasDrop ? "Chapter II" : "")
                            .font(.system(size: 12, weight: .bold)).tracking(0.12)
                            .foregroundColor(theme.accentInk)
                            .frame(maxWidth: 660, alignment: .leading)

                        Text("Where I Lived, and What I Lived For")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(theme.ink)
                            .frame(maxWidth: 660, alignment: .leading)
                            .padding(.top, 10).padding(.bottom, 30)

                        ForEach(Array(MockData.readerParas.enumerated()), id: \.offset) { idx, para in
                            ParaView(
                                para: para,
                                index: idx,
                                activeHL: highlights[idx],
                                isSelected: selectedPara == idx,
                                onTap: { selectedPara = selectedPara == idx ? nil : idx },
                                onHighlight: { color in
                                    if let c = color {
                                        highlights[idx] = c
                                    } else {
                                        highlights.removeValue(forKey: idx)
                                    }
                                    selectedPara = nil
                                }
                            )
                        }
                    }
                    .frame(maxWidth: 660)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 56)
                    .frame(maxWidth: .infinity)
                }
                .background(theme.reader)

                // Footer
                HStack {
                    Text("Page 84 of 312 · 42% · about 9 min left in chapter")
                        .font(.system(size: 12)).foregroundColor(theme.ink3)
                }
                .frame(height: 42)
                .background(theme.reader)
            }
        }
        .background(theme.reader)
    }
}

// MARK: - Paragraph View

struct ParaView: View {
    @EnvironmentObject var theme: AppTheme
    let para: ReaderPara
    let index: Int
    let activeHL: HLColor?
    let isSelected: Bool
    var onTap: () -> Void
    var onHighlight: (HLColor?) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onTap) {
                Group {
                    if para.hasDrop {
                        // Drop cap paragraph
                        Text(String(para.text.prefix(1)))
                            .font(.system(size: 58, weight: .bold))
                            .foregroundColor(theme.ink)
                        + Text(String(para.text.dropFirst()))
                            .font(.system(size: 19))
                            .foregroundColor(activeHL?.textColor ?? theme.ink)
                    } else {
                        Text(para.text)
                            .font(.system(size: 19))
                            .foregroundColor(activeHL?.textColor ?? theme.ink)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(activeHL?.color ?? (isSelected ? theme.accentSoft : Color.clear))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .lineSpacing(8)
            }
            .buttonStyle(.plain)

            // Highlight color picker
            if isSelected {
                HStack(spacing: 8) {
                    ForEach(HLColor.allCases, id: \.self) { c in
                        Button {
                            onHighlight(activeHL == c ? nil : c)
                        } label: {
                            Circle()
                                .fill(c.color)
                                .frame(width: 24, height: 24)
                                .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(7)
                .background(theme.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(theme.line2, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 2)
                .offset(y: -44)
                .zIndex(5)
            }
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Icon Button Style (macOS)
// ButtonStyle cannot use @EnvironmentObject — colors are passed as values.

struct IconBtnStyle: ButtonStyle {
    var ink2Color: Color
    var surface2Color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(ink2Color)
            .frame(width: 34, height: 34)
            .background(configuration.isPressed ? surface2Color : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
