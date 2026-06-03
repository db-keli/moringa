import SwiftUI

struct MEditorView: View {
    @Environment(AppTheme.self) var theme
    let draft: Draft
    var onBack: () -> Void

    var body: some View {
        ZStack {
            theme.reader.ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar
                HStack {
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

                    HStack(spacing: 5) {
                        Image(systemName: "checkmark").font(.system(size: 12))
                        Text("Saved").font(.system(size: 12.5))
                    }
                    .foregroundColor(theme.accentInk)
                }
                .padding(.horizontal, 16)
                .padding(.top, 58)
                .padding(.bottom, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(draft.title)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(draft.words) words · edited \(draft.edited)")
                            .font(.system(size: 12)).foregroundColor(theme.ink3)
                            .padding(.top, 6).padding(.bottom, 14)

                        ForEach(Array(draft.paragraphs.enumerated()), id: \.offset) { _, para in
                            if para.isHeading {
                                Text(para.text)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(theme.ink)
                                    .padding(.top, 18).padding(.bottom, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(para.text)
                                    .font(.system(size: 16.5)).lineSpacing(5)
                                    .foregroundColor(theme.ink)
                                    .padding(.bottom, 14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 80)
                }
            }
        }
    }
}
