import SwiftUI

struct BookCoverView: View {
    let book: Book
    var small: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                book.color

                VStack(alignment: .leading, spacing: 0) {
                    Text(book.title)
                        .font(.system(size: small ? 11 : 15, weight: .bold))
                        .lineLimit(small ? 3 : 4)
                        .foregroundColor(.white)

                    Spacer(minLength: 0)

                    Rectangle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 22, height: 2)
                        .padding(.bottom, 8)

                    Text(book.author.uppercased())
                        .font(.system(size: small ? 8 : 10.5, weight: .semibold))
                        .tracking(small ? 0.03 : 0.04)
                        .foregroundColor(.white.opacity(0.82))
                        .lineLimit(2)
                }
                .padding(small ? 11 : 16)

                // inner shine
                RoundedRectangle(cornerRadius: small ? 5 : 6)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.18), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            }
        }
        .aspectRatio(2/3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: small ? 5 : 6))
        .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
    }
}
