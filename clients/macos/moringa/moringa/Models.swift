import SwiftUI

// MARK: - Domain models

struct Book: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let colorHex: String
    var progress: Double
    var isReading: Bool = false
    var color: Color { Color(hex: colorHex) }
}

enum HLColor: String, CaseIterable {
    case yellow, green, blue, pink
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .yellow: return M.hlYellow
        case .green:  return M.hlGreen
        case .blue:   return M.hlBlue
        case .pink:   return M.hlPink
        }
    }
    var textColor: Color {
        switch self {
        case .yellow: return Color(hex: "3a3320")
        case .green:  return Color(hex: "1f3424")
        case .blue:   return Color(hex: "1d3147")
        case .pink:   return Color(hex: "46202d")
        }
    }
}

struct Highlight: Identifiable {
    let id: String
    let bookId: String
    let color: HLColor
    let text: String
    let loc: String
    let date: String
    var note: String?
}

struct Note: Identifiable {
    let id: String
    let title: String
    let bookId: String?
    let date: String
    let body: String
}

struct DraftPara {
    let isHeading: Bool
    let text: String
}

enum DraftStatus: String { case draft, published }

struct Draft: Identifiable {
    let id: String
    let title: String
    let status: DraftStatus
    let words: Int
    let edited: String
    let excerpt: String
    let paragraphs: [DraftPara]
}

struct DeviceInfo: Identifiable {
    let id = UUID()
    let name: String
    let kind: String  // "mac" | "phone"
    let seq: Int
    let last: String
    let isCurrent: Bool
}

struct SyncInfo {
    let lastSynced: String
    let queue: Int
    let clockMac: Int
    let clockPhone: Int
    let server: String
    let region: String
    let devices: [DeviceInfo]
    let cachedBooks: Int
    let cacheSize: String
}

struct ReaderPara {
    let text: String
    let hasDrop: Bool
    let highlight: HLColor?
}

// MARK: - Mock data

enum MockData {
    static let books: [Book] = [
        Book(id:"walden",     title:"Walden",                               author:"Henry David Thoreau",   colorHex:"2F5D50", progress:0.42, isReading:true),
        Book(id:"tinker",     title:"Pilgrim at Tinker Creek",              author:"Annie Dillard",         colorHex:"7C4A30", progress:0.18),
        Book(id:"rilke",      title:"Letters to a Young Poet",              author:"Rainer Maria Rilke",    colorHex:"3A4A6B", progress:0.91),
        Book(id:"birdbybird", title:"Bird by Bird",                         author:"Anne Lamott",           colorHex:"9C7A2E", progress:0.66),
        Book(id:"meditations",title:"Meditations",                          author:"Marcus Aurelius",       colorHex:"55402F", progress:0.30),
        Book(id:"order",      title:"The Order of Time",                    author:"Carlo Rovelli",         colorHex:"2B4D63", progress:0),
        Book(id:"arttravel",  title:"The Art of Travel",                    author:"Alain de Botton",       colorHex:"6E3B43", progress:0),
        Book(id:"onwriting",  title:"On Writing",                           author:"Stephen King",          colorHex:"3C3C40", progress:1),
        Book(id:"seeing",     title:"Seeing Like a State",                  author:"James C. Scott",        colorHex:"4A5A36", progress:0),
        Book(id:"pattern",    title:"A Pattern Language",                   author:"Christopher Alexander", colorHex:"8A5A2B", progress:1),
        Book(id:"information",title:"The Information",                      author:"James Gleick",          colorHex:"233A4D", progress:0),
        Book(id:"cities",     title:"Death & Life of Great American Cities",author:"Jane Jacobs",           colorHex:"704830", progress:0),
        Book(id:"taoteching", title:"Tao Te Ching",                         author:"Lao Tzu",               colorHex:"3E5648", progress:0.55),
        Book(id:"gleam",      title:"The Glass Bead Game",                  author:"Hermann Hesse",         colorHex:"4C4068", progress:0),
    ]
    static var readingNow: Book { books.first(where:{ $0.isReading }) ?? books[0] }
    static let readingNowChapter = "Where I Lived, and What I Lived For"
    static let readingNowQuote   = "I went to the woods because I wished to live deliberately, to front only the essential facts of life."

    static let readerParas: [ReaderPara] = [
        .init(text:"At a certain season of our life we are accustomed to consider every spot as the possible site of a house. I have thus surveyed the country on every side within a dozen miles of where I live. In imagination I have bought all the farms in succession, for all were to be bought, and I knew their price.", hasDrop:true, highlight:nil),
        .init(text:"I went to the woods because I wished to live deliberately, to front only the essential facts of life, and see if I could not learn what it had to teach, and not, when I came to die, discover that I had not lived.", hasDrop:false, highlight:.yellow),
        .init(text:"I did not wish to live what was not life, living is so dear; nor did I wish to practise resignation, unless it was quite necessary. I wanted to live deep and suck out all the marrow of life.", hasDrop:false, highlight:nil),
        .init(text:"Our life is frittered away by detail. Simplicity, simplicity, simplicity! I say, let your affairs be as two or three, and not a hundred or a thousand.", hasDrop:false, highlight:.green),
        .init(text:"Why should we live with such hurry and waste of life? We are determined to be starved before we are hungry. Men say that a stitch in time saves nine, and so they take a thousand stitches today to save nine tomorrow.", hasDrop:false, highlight:nil),
        .init(text:"Time is but the stream I go a-fishing in. I drink at it; but while I drink I see the sandy bottom and detect how shallow it is. Its thin current slides away, but eternity remains.", hasDrop:false, highlight:nil),
    ]

    static let highlights: [Highlight] = [
        .init(id:"h1", bookId:"walden",     color:.yellow, text:"I went to the woods because I wished to live deliberately, to front only the essential facts of life.", loc:"Ch. II · p.84", date:"2 days ago", note:"The thesis of the whole book in one breath."),
        .init(id:"h2", bookId:"walden",     color:.green,  text:"Simplicity, simplicity, simplicity! I say, let your affairs be as two or three.", loc:"Ch. II · p.88", date:"2 days ago"),
        .init(id:"h3", bookId:"rilke",      color:.blue,   text:"Be patient toward all that is unsolved in your heart and try to love the questions themselves.", loc:"Letter 4 · p.34", date:"5 days ago", note:"For the essay on uncertainty."),
        .init(id:"h4", bookId:"birdbybird", color:.yellow, text:"You own everything that happened to you. Tell your stories.", loc:"p.6", date:"1 week ago"),
        .init(id:"h5", bookId:"meditations",color:.pink,   text:"You have power over your mind — not outside events. Realize this, and you will find strength.", loc:"Book VII", date:"1 week ago", note:"Stoic core. Compare with the Tao Te Ching note."),
        .init(id:"h6", bookId:"tinker",     color:.green,  text:"Beauty and grace are performed whether or not we will or sense them. The least we can do is try to be there.", loc:"p.10", date:"2 weeks ago"),
        .init(id:"h7", bookId:"taoteching", color:.blue,   text:"Nature does not hurry, yet everything is accomplished.", loc:"Verse 73", date:"2 weeks ago"),
        .init(id:"h8", bookId:"onwriting",  color:.yellow, text:"The scariest moment is always just before you start. After that, things can only get better.", loc:"p.269", date:"3 weeks ago"),
    ]

    static let notes: [Note] = [
        .init(id:"n1", title:"On living deliberately",  bookId:"walden",     date:"2 days ago",  body:"Thoreau's \"deliberately\" isn't austerity for its own sake — it's about removing what obscures the signal. Maps to local-first: keep the essential facts close, let everything else sync in the background."),
        .init(id:"n2", title:"Questions worth keeping", bookId:"rilke",      date:"5 days ago",  body:"Rilke: love the questions themselves. A reading app should make it easy to hold an open question across weeks — a place for half-formed thoughts that don't resolve yet."),
        .init(id:"n3", title:"Stoic vs. Taoist agency", bookId:nil,          date:"1 week ago",  body:"Marcus: power over the mind, not events. Lao Tzu: nature does not hurry. Two routes to the same calm — one through will, one through release."),
        .init(id:"n4", title:"Why I self-host",         bookId:nil,          date:"1 week ago",  body:"Started as a privacy thing. Now it's mostly about permanence — I want my highlights to outlive any company. One server, one backup, files I can read in a text editor in twenty years."),
        .init(id:"n5", title:"Reading rhythm",          bookId:"birdbybird", date:"2 weeks ago", body:"Bird by bird = one chapter at a time. Stop measuring books finished; measure mornings spent reading."),
        .init(id:"n6", title:"Footnotes as a feature",  bookId:nil,          date:"3 weeks ago", body:"The best margin notes are conversations with the author. Highlight + note in one gesture. Don't separate them in the UI."),
    ]

    static let drafts: [Draft] = [
        Draft(id:"d1", title:"Notes on local-first software", status:.draft, words:1240, edited:"12 minutes ago",
              excerpt:"Every read and write goes to the device first. The server is a sync bus, not an authority.",
              paragraphs:[
                .init(isHeading:false, text:"Every read and write goes to the device first. The server is a sync bus, not an authority. That single decision changes how the whole thing feels."),
                .init(isHeading:false, text:"Waiting 80ms for a server round-trip on every keystroke is the difference between a tool that feels native and one that feels like a web page pretending to be an app. SQLite on disk is effectively zero."),
                .init(isHeading:true,  text:"What offline actually buys you"),
                .init(isHeading:false, text:"The obvious win is the airplane. The real win is trust. When the network is never on the critical path, the app stops flinching. Nothing spins. Nothing is \"saving…\". You stop thinking about it, which is the highest compliment software can earn."),
              ]),
        Draft(id:"d2", title:"Why I left the cloud (mostly)", status:.draft, words:870, edited:"yesterday",
              excerpt:"I didn't leave for ideology. I left because I wanted my highlights to outlive the companies that stored them.",
              paragraphs:[.init(isHeading:false, text:"I didn't leave for ideology. I left because I wanted my highlights to outlive the companies that stored them.")]),
        Draft(id:"d3", title:"Reading in the age of distraction", status:.draft, words:430, edited:"3 days ago",
              excerpt:"A book is a single-tasking device disguised as a stack of paper.",
              paragraphs:[.init(isHeading:false, text:"A book is a single-tasking device disguised as a stack of paper. That is the whole technology, and we keep trying to improve it by adding the very things it was built to exclude.")]),
        Draft(id:"d4", title:"A week with no notifications", status:.published, words:1520, edited:"Mar 14",
              excerpt:"Seven days, every badge off. A field report on what came back when the interruptions stopped.",
              paragraphs:[.init(isHeading:false, text:"Seven days, every badge off. Here is a field report on what came back when the interruptions stopped.")]),
        Draft(id:"d5", title:"The case for owning your data", status:.published, words:2100, edited:"Feb 28",
              excerpt:"Convenience is a loan against your future autonomy. The interest compounds quietly.",
              paragraphs:[.init(isHeading:false, text:"Convenience is a loan against your future autonomy, and the interest compounds quietly.")]),
    ]

    static func book(id: String) -> Book? { books.first(where:{ $0.id == id }) }

    static let sync = SyncInfo(
        lastSynced:"just now", queue:0, clockMac:44, clockPhone:31,
        server:"reader.home.arpa", region:"self-hosted · Frankfurt VPS",
        devices:[
            DeviceInfo(name:"MacBook Air", kind:"mac",   seq:44, last:"just now",       isCurrent:true),
            DeviceInfo(name:"iPhone 15",   kind:"phone", seq:31, last:"4 minutes ago",  isCurrent:false),
        ],
        cachedBooks:14, cacheSize:"182 MB"
    )
}
