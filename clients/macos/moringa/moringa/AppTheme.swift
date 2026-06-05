import SwiftUI
import Observation

// MARK: - Hex Color
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        self.init(.sRGB,
                  red:   Double((n >> 16) & 0xFF) / 255,
                  green: Double((n >>  8) & 0xFF) / 255,
                  blue:  Double( n        & 0xFF) / 255)
    }
}

// MARK: - Static tokens
enum M {
    static let accentInkL   = Color(hex: "3C8455")
    static let accentInkD   = Color(hex: "6FC08C")

    static let hlYellow = Color(hex: "F2D578")
    static let hlGreen  = Color(hex: "ADD8B0")
    static let hlBlue   = Color(hex: "A9CCEA")
    static let hlPink   = Color(hex: "E6B6C4")

    // light
    static let lPaper    = Color(hex: "FFFFFF")
    static let lSidebar  = Color(hex: "FFFFFF")
    static let lSurface  = Color(hex: "FFFFFF")
    static let lSurface2 = Color(hex: "FFFFFF")
    static let lSurface3 = Color(hex: "FFFFFF")
    static let lInk      = Color(hex: "24292B")
    static let lInk2     = Color(hex: "5E625F")
    static let lInk3     = Color(hex: "948F86")
    static let lLine     = Color(hex: "E5E5E5")
    static let lLine2    = Color(hex: "D4D4D4")
    static let lReader   = Color(hex: "FFFFFF")

    // dark
    static let dPaper    = Color(hex: "14191A")
    static let dSidebar  = Color(hex: "0E1314")
    static let dSurface  = Color(hex: "1B2123")
    static let dSurface2 = Color(hex: "222A2B")
    static let dSurface3 = Color(hex: "2A3335")
    static let dInk      = Color(hex: "EAE7DE")
    static let dInk2     = Color(hex: "9FA6A2")
    static let dInk3     = Color(hex: "6C736F")
    static let dLine     = Color(hex: "28302F")
    static let dLine2    = Color(hex: "333C3A")
    static let dReader   = Color(hex: "161B1C")
}

// MARK: - AppTheme  (@Observable — Swift 6 / Xcode 26)
@Observable
final class AppTheme {
    var isDark: Bool = false {
        didSet { UserDefaults.standard.set(isDark, forKey: "moringa.dark") }
    }
    var accentHex: String = "4E9D6A" {
        didSet { UserDefaults.standard.set(accentHex, forKey: "moringa.accentHex") }
    }
    var readerSize: Double = 19 {
        didSet { UserDefaults.standard.set(readerSize, forKey: "moringa.readerSize") }
    }

    init() {
        isDark    = UserDefaults.standard.bool(forKey: "moringa.dark")
        if let s  = UserDefaults.standard.string(forKey: "moringa.accentHex") { accentHex = s }
        let rs    = UserDefaults.standard.double(forKey: "moringa.readerSize")
        if rs > 0 { readerSize = rs }
    }

    var accent:     Color { Color(hex: accentHex) }
    var accentInk:  Color { isDark ? M.accentInkD : M.accentInkL }
    var accentSoft: Color { accent.opacity(isDark ? 0.16 : 0.14) }

    var paper:    Color { isDark ? M.dPaper    : M.lPaper }
    var sidebar:  Color { isDark ? M.dSidebar  : M.lSidebar }
    var surface:  Color { isDark ? M.dSurface  : M.lSurface }
    var surface2: Color { isDark ? M.dSurface2 : M.lSurface2 }
    var surface3: Color { isDark ? M.dSurface3 : M.lSurface3 }
    var ink:      Color { isDark ? M.dInk      : M.lInk }
    var ink2:     Color { isDark ? M.dInk2     : M.lInk2 }
    var ink3:     Color { isDark ? M.dInk3     : M.lInk3 }
    var line:     Color { isDark ? M.dLine     : M.lLine }
    var line2:    Color { isDark ? M.dLine2    : M.lLine2 }
    var reader:   Color { isDark ? M.dReader   : M.lReader }

    let accentPresets = ["4E9D6A", "2E6B43", "5B8C5A", "3F7D54"]
}
