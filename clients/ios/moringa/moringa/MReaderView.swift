import SwiftUI

struct MReaderView: View {
    @EnvironmentObject var theme: AppTheme
    let book: Book
    var onBack: () -> Void

    var body: some View {
        ZStack {
            theme.reader.ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 10) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.ink2)
                            .frame(width: 38, height: 38)
                            .background(theme.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(book.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.ink)
                        .lineLimit(1)

                    Spacer()

                    Button { } label: {
                        Image(systemName: "textformat.size")
                            .font(.system(size: 16))
                            .foregroundColor(theme.ink2)
                            .frame(width: 38, height: 38)
                            .background(theme.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 58)
                .padding(.bottom, 10)
                .background(theme.reader)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Chapter II")
                            .font(.system(size: 11, weight: .bold)).tracking(0.12)
                            .foregroundColor(theme.accentInk)

                        Text("Where I Lived, and What I Lived For")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundColor(theme.ink)
                            .padding(.top, 9).padding(.bottom, 22)

                        ForEach(Array(MockData.readerParas.enumerated()), id: \.offset) { _, para in
                            Group {
                                if let hl = para.highlight {
                                    Text(para.text)
                                        .padding(4)
                                        .background(hl.color)
                                        .foregroundColor(hl.textColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                } else {
                                    Text(para.text)
                                        .foregroundColor(theme.ink)
                                }
                            }
                            .font(.system(size: 18))
                            .lineSpacing(7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 18)
                        }
                    }
                    .padding(.horizontal, 24).padding(.vertical, 24).padding(.bottom, 60)
                }

                // Footer
                HStack {
                    Text("42% · about 9 min left in chapter")
                        .font(.system(size: 12)).foregroundColor(theme.ink3)
                }
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(theme.reader)
                .overlay(alignment: .top) { Divider().background(theme.line) }
            }
        }
    }
}
