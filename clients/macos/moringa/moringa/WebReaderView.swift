import SwiftUI
import WebKit

// MARK: - WKWebView wrapper (macOS)

struct WebReaderView: NSViewRepresentable {
    let html: String
    let isDark: Bool
    let fontSize: Double
    var onScrollPct: ((Double) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "scrollHandler")
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.setValue(false, forKey: "drawsBackground")
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
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

// MARK: - Styled HTML

func styledPage(_ body: String, isDark: Bool, fontSize: Double) -> String {
    let bg      = isDark ? "#161B1C" : "#F7F3EB"
    let ink     = isDark ? "#EAE7DE" : "#24292B"
    let ink2    = isDark ? "#9FA6A2" : "#5E625F"
    let accent  = "#4E9D6A"
    let hlY     = "#F2D578"
    let hlG     = "#ADD8B0"
    let hlB     = "#A9CCEA"
    let hlP     = "#E6B6C4"

    return """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    html, body {
        background: \(bg);
        color: \(ink);
        font-family: -apple-system, 'Helvetica Neue', sans-serif;
        font-size: \(fontSize)px;
        line-height: 1.72;
        -webkit-font-smoothing: antialiased;
    }
    .page {
        max-width: 660px;
        margin: 0 auto;
        padding: 40px 32px 120px;
    }
    h1 { font-size: 1.8em; font-weight: 700; letter-spacing: -0.02em; margin: 0 0 0.75em; }
    h2 { font-size: 1.3em; font-weight: 700; margin: 1.4em 0 0.5em; }
    h3 { font-size: 1.1em; font-weight: 600; margin: 1.2em 0 0.4em; }
    p  { margin: 0 0 1.2em; text-wrap: pretty; }
    a  { color: \(accent); text-decoration: none; }
    .hl-yellow { background: \(hlY); border-radius: 3px; padding: 1px 0; }
    .hl-green  { background: \(hlG); border-radius: 3px; padding: 1px 0; }
    .hl-blue   { background: \(hlB); border-radius: 3px; padding: 1px 0; }
    .hl-pink   { background: \(hlP); border-radius: 3px; padding: 1px 0; }
    blockquote {
        border-left: 3px solid \(accent);
        padding-left: 1em;
        margin: 1em 0;
        color: \(ink2);
    }
    img { max-width: 100%; border-radius: 8px; }
    </style>
    <script>
    window.addEventListener('scroll', function() {
        var pct = window.scrollY / (document.body.scrollHeight - window.innerHeight);
        window.webkit.messageHandlers.scrollHandler.postMessage(Math.min(1, Math.max(0, pct)));
    });
    </script>
    </head>
    <body>
    <div class="page">
    \(body)
    </div>
    </body>
    </html>
    """
}
