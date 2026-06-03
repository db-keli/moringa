import SwiftUI

struct DraftsView: View {
    @EnvironmentObject var theme: AppTheme
    @State private var selectedId: String = MockData.drafts[0].id

    var selected: Draft { MockData.drafts.first(where: { $0.id == selectedId }) ?? MockData.drafts[0] }

    var body: some View {
        HStack(spacing: 0) {
            // Draft list
            VStack(spacing: 0) {
                HStack {
                    Text("Drafts").font(.system(size: 20, weight: .bold)).foregroundColor(theme.ink)
                    Spacer()
                    Button {
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                            Text("New").font(.system(size: 13.5, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).frame(height: 30)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18).frame(height: 58)
                .overlay(alignment: .bottom) { Divider().background(theme.line) }

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(MockData.drafts) { d in
                            Button { selectedId = d.id } label: {
                                DraftRowView(draft: d, isActive: d.id == selectedId)
                            }
                            .buttonStyle(.plain)
                            Divider().background(theme.line)
                        }
                    }
                }
            }
            .frame(width: 300)
            .background(theme.paper)
            .overlay(alignment: .trailing) { Divider().background(theme.line) }

            // Editor
            VStack(spacing: 0) {
                // Editor bar
                HStack(spacing: 10) {
                    DraftStatusBadge(status: selected.status)
                    Text("\(selected.words) words").font(.system(size: 12.5)).foregroundColor(theme.ink3)
                    Text("·").foregroundColor(theme.ink3)
                    Text("Edited \(selected.edited)").font(.system(size: 12.5)).foregroundColor(theme.ink3)
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark").font(.system(size: 12))
                        Text("Saved locally").font(.system(size: 12.5))
                    }
                    .foregroundColor(theme.accentInk)
                }
                .padding(.horizontal, 22).frame(height: 50)
                .overlay(alignment: .bottom) { Divider().background(theme.line) }

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Title", text: .constant(selected.title))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(theme.ink)
                            .textFieldStyle(.plain)
                            .padding(.bottom, 8)

                        ForEach(Array(selected.paragraphs.enumerated()), id: \.offset) { _, para in
                            if para.isHeading {
                                Text(para.text)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(theme.ink)
                                    .padding(.top, 22).padding(.bottom, 8)
                            } else {
                                Text(para.text)
                                    .font(.system(size: 17.5))
                                    .foregroundColor(theme.ink)
                                    .lineSpacing(6)
                                    .padding(.bottom, 16)
                            }
                        }
                    }
                    .frame(maxWidth: 680)
                    .padding(.horizontal, 32).padding(.vertical, 44)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(theme.reader)
        }
    }
}

struct DraftRowView: View {
    @EnvironmentObject var theme: AppTheme
    let draft: Draft
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(draft.title)
                .font(.system(size: 14.5, weight: .bold))
                .foregroundColor(theme.ink)
                .lineLimit(1)
            Text(draft.excerpt)
                .font(.system(size: 12.5)).lineSpacing(2)
                .foregroundColor(theme.ink2)
                .lineLimit(2)
            HStack(spacing: 8) {
                DraftStatusBadge(status: draft.status)
                Text("\(draft.words) words").font(.system(size: 11.5)).foregroundColor(theme.ink3)
                Spacer()
                Text(draft.edited).font(.system(size: 11.5)).foregroundColor(theme.ink3)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 18).padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isActive ? theme.accentSoft : Color.clear)
    }
}

struct DraftStatusBadge: View {
    @EnvironmentObject var theme: AppTheme
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
