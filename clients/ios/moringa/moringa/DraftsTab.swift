import SwiftUI

struct DraftsTab: View {
    @Environment(AppTheme.self) var theme
    @Environment(Store.self)   var store
    var openDraft: (Draft) -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Text("Drafts").font(.system(size: 30, weight: .bold)).foregroundColor(theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 8)
                    .background(theme.paper)

                if store.drafts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "pencil.line").font(.system(size: 40)).foregroundColor(theme.ink3)
                        Text("No drafts").font(.system(size: 17, weight: .semibold)).foregroundColor(theme.ink)
                        Text("Tap + to start writing.").font(.system(size: 14)).foregroundColor(theme.ink3)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(store.drafts) { d in
                                Button { openDraft(d) } label: {
                                    MDraftCard(draft: d)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).padding(.horizontal, 20)
                            }
                            Spacer(minLength: 30)
                        }.padding(.top, 12)
                    }
                }
            }

            Button { store.createDraft() } label: {
                Image(systemName: "plus").font(.system(size: 22, weight: .semibold)).foregroundColor(.white)
                    .frame(width: 52, height: 52).background(theme.accent).clipShape(Circle())
                    .shadow(color: theme.accent.opacity(0.45), radius: 12, x: 0, y: 4)
            }.buttonStyle(.plain).padding(.trailing, 18).padding(.bottom, 10)
        }
    }
}

struct MDraftCard: View {
    @Environment(AppTheme.self) var theme
    let draft: Draft
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(draft.title).font(.system(size: 16, weight: .bold)).foregroundColor(theme.ink).lineLimit(1)
            Text(draft.excerpt).font(.system(size: 13)).lineSpacing(3).foregroundColor(theme.ink2).lineLimit(2)
            HStack(spacing: 8) {
                MDraftBadge(status: draft.status)
                Text("\(draft.wordCount) words").font(.system(size: 11.5)).foregroundColor(theme.ink3)
                Spacer()
                Text(draft.updatedAt.prefix(10)).font(.system(size: 11.5)).foregroundColor(theme.ink3)
            }.padding(.top, 4)
        }
        .padding(16).background(theme.surface).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

struct MDraftBadge: View {
    @Environment(AppTheme.self) var theme
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
