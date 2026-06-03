import SwiftUI
import WebKit

// MARK: - WKWebView wrapper (iOS)

struct WebReaderView: UIViewRepresentable {
    let html: String
    let isDark: Bool
    let fontSize: Double
    var onScrollPct: ((Double) -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "scrollHandler")
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.backgroundColor = .clear
        wv.isOpaque = false
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        context.coordinator.onScrollPct = onScrollPct
        wv.loadHTMLString(styledPage(html, isDark: isDark, fontSize: fontSize), baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onScrollPct: ((Double) -> Void)?

        func userContentController(_ ctrl: WKUserContentController, didReceive msg: WKScriptMessage) {
            if msg.name == "scrollHandler", let pct = msg.body as? Double {
                onScrollPct?(pct)
            }
        }
    }
}
