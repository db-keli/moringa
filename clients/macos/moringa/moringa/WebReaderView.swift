import SwiftUI
import WebKit

// MARK: - WKWebView wrapper (macOS)

struct WebReaderView: NSViewRepresentable {
    let chapterURL: URL?      // load from server when available (nil = offline fallback)
    let html: String          // offline fallback body HTML
    let isDark: Bool
    let fontSize: Double
    var highlights: [Highlight] = []
    var onScrollPct: ((Double) -> Void)?
    var onTextSelected: ((String) -> Void)?
    var onChapterLink: ((String) -> Void)?   // called with the linked chapter's filename

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let uc = config.userContentController
        uc.add(context.coordinator, name: "scrollHandler")
        uc.add(context.coordinator, name: "selectionHandler")
        uc.addUserScript(WKUserScript(
            source: layoutCSS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        // Inject the stable JS (no isDark/fontSize dependency) at document end
        uc.addUserScript(WKUserScript(
            source: readerJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.setValue(false, forKey: "drawsBackground")
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        let c = context.coordinator
        c.onScrollPct    = onScrollPct
        c.onTextSelected = onTextSelected
        c.onChapterLink  = onChapterLink
        c.webView        = wv
        c.isDark         = isDark
        c.fontSize       = fontSize
        c.highlights     = highlights

        let urlChanged  = c.loadedURL  != chapterURL
        let htmlChanged = c.loadedHTML != html

        if urlChanged || (chapterURL == nil && htmlChanged) {
            // Load new chapter
            c.loadedURL  = chapterURL
            c.loadedHTML = html

            if let url = chapterURL {
                wv.load(URLRequest(url: url))
            } else {
                // Offline: wrap chunk HTML in a minimal shell
                wv.loadHTMLString(offlineShell(html), baseURL: nil)
            }
            // CSS + highlights injected in didFinish
        } else if c.loadedIsDark != isDark || c.loadedFontSize != fontSize {
            // Settings changed — update CSS without reloading
            c.loadedIsDark   = isDark
            c.loadedFontSize = fontSize
            c.injectCSS(into: wv)
        } else {
            // Only highlights changed
            c.injectHighlights(into: wv)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onScrollPct: ((Double) -> Void)?
        var onTextSelected: ((String) -> Void)?
        var onChapterLink: ((String) -> Void)?
        var highlights: [Highlight] = []
        weak var webView: WKWebView?

        var isDark: Bool   = false
        var fontSize: Double = 18

        var loadedURL: URL?     = nil
        var loadedHTML: String  = ""
        var loadedIsDark: Bool  = false
        var loadedFontSize: Double = 0

        // MARK: Message handling

        func userContentController(_ ctrl: WKUserContentController, didReceive msg: WKScriptMessage) {
            switch msg.name {
            case "scrollHandler":
                if let pct = msg.body as? Double { onScrollPct?(pct) }
            case "selectionHandler":
                if let text = msg.body as? String, !text.isEmpty { onTextSelected?(text) }
            default: break
            }
        }

        // MARK: Navigation

        func webView(_ wv: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard action.navigationType == .linkActivated,
                  let url = action.request.url else {
                decisionHandler(.allow)
                return
            }
            // Intercept chapter-to-chapter links and route them through the reader
            let ext = url.pathExtension.lowercased()
            if ext == "xhtml" || ext == "html" || ext == "htm" || ext.isEmpty {
                onChapterLink?(url.lastPathComponent)
                decisionHandler(.cancel)
                return
            }
            // Let the WebView handle anything else (e.g. anchor fragments handled internally)
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loadedIsDark   = isDark
            loadedFontSize = fontSize
            injectCSS(into: webView)
            injectHighlights(into: webView)
        }

        // MARK: CSS injection

        func injectCSS(into wv: WKWebView) {
            let bg  = isDark ? "#161B1C" : "#FFFFFF"
            let ink = isDark ? "#EAE7DE" : "#1A1A1A"
            let css = """
                html { font-size: \(fontSize)px; }
                html, body { background: \(bg) !important; color: \(ink) !important; }
                .hl-yellow { background: #F2D578 !important; border-radius: 3px; padding: 1px 0; }
                .hl-green  { background: #ADD8B0 !important; border-radius: 3px; padding: 1px 0; }
                .hl-blue   { background: #A9CCEA !important; border-radius: 3px; padding: 1px 0; }
                .hl-pink   { background: #E6B6C4 !important; border-radius: 3px; padding: 1px 0; }
            """
            let escaped = css
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`",  with: "\\`")
            wv.evaluateJavaScript("""
                (function() {
                    var s = document.getElementById('moringa-overrides');
                    if (!s) {
                        s = document.createElement('style');
                        s.id = 'moringa-overrides';
                        (document.head || document.documentElement).appendChild(s);
                    }
                    s.textContent = `\(escaped)`;
                })();
            """, completionHandler: nil)
        }

        // MARK: Highlight injection

        func injectHighlights(into wv: WKWebView) {
            let hlData = highlights.map { ["loc": $0.loc, "color": $0.color.rawValue] }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: hlData),
                  let json = String(data: jsonData, encoding: .utf8) else { return }
            wv.evaluateJavaScript("window.loadHighlights(\(json))", completionHandler: nil)
        }
    }
}

// MARK: - Offline fallback shell

private func offlineShell(_ body: String) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    </head>
    <body>
    \(body)
    </body>
    </html>
    """
}

// MARK: - Static layout CSS (injected at document start to prevent FOUC)

private let layoutCSS = """
(function() {
    var s = document.createElement('style');
    s.id = 'moringa-layout';
    s.textContent = `
        *, *::before, *::after { box-sizing: border-box; }
        html { overflow-x: hidden; -webkit-text-size-adjust: 100%; -webkit-font-smoothing: antialiased; }
        body {
            max-width: 720px !important;
            margin-left: auto !important;
            margin-right: auto !important;
            padding: 40px 40px 100px !important;
            overflow-x: hidden;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        img {
            float: none !important; clear: both !important; display: block !important;
            max-width: 100% !important; width: auto !important; height: auto !important;
            margin: 1em auto !important;
        }
        figure, svg {
            float: none !important; clear: both !important; display: block !important;
            max-width: 100% !important; margin: 1em auto !important; text-align: center;
        }
        body::after, section::after, article::after, aside::after, div::after,
        blockquote::after, li::after, td::after, th::after {
            content: ''; display: table; clear: both;
        }
        video, audio, iframe, canvas { max-width: 100% !important; height: auto; }
        table { max-width: 100% !important; overflow-x: auto; display: block; border-collapse: collapse; }
        td, th { word-break: break-word; }
        pre, code { white-space: pre-wrap !important; word-break: break-word; overflow-wrap: break-word; }
        .hl-yellow { background: #F2D578 !important; border-radius: 3px; padding: 1px 0; }
        .hl-green  { background: #ADD8B0 !important; border-radius: 3px; padding: 1px 0; }
        .hl-blue   { background: #A9CCEA !important; border-radius: 3px; padding: 1px 0; }
        .hl-pink   { background: #E6B6C4 !important; border-radius: 3px; padding: 1px 0; }
    `;
    (document.head || document.documentElement).appendChild(s);
})();
"""

// MARK: - Reader JS (injected at document end — no isDark/fontSize dependency)

private let readerJS = """
// ── Character-offset helpers ─────────────────────────────────────────────────
//
// bodyTextLength(container, offset) — returns the number of characters from
// the start of document.body up to (container, offset).
//
// Using Range.toString() handles BOTH cases:
//   • container is a text node  → offset is a character index within it
//   • container is an element   → offset is a child-node index within it
// The old getTextOffset(textNode, charIndex) approach would return -1 whenever
// the selection endpoint landed on an element boundary (e.g. start/end of a
// paragraph), silently discarding any multi-line or cross-paragraph selection.
//
// bodyTextLength — count characters from the start of document.body up to
// (container, offset) using the same TreeWalker that resolveTextOffset uses.
// This guarantees the two functions agree on every character, including text
// inside hidden elements (display:none page markers etc.) that Range.toString()
// silently skips but TreeWalker always visits.
function bodyTextLength(container, offset) {
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
    var total = 0, n;
    while ((n = walker.nextNode())) {
        if (container.nodeType === Node.TEXT_NODE) {
            // Simple case: container is a text node.
            if (n === container) return total + offset;
            total += n.nodeValue.length;
        } else {
            // Element container: offset is a child-node index.
            // Count text nodes that appear BEFORE container.childNodes[offset].
            var pivot = container.childNodes[offset] || null;
            if (pivot === null) {
                // offset == childNodes.length → after all children of container.
                if (container.contains(n)) { total += n.nodeValue.length; }
                else                        { return total; }
            } else {
                // n.compareDocumentPosition(pivot) has DOCUMENT_POSITION_FOLLOWING (4)
                // set when pivot comes AFTER n, i.e. n is before pivot → count it.
                if (n.compareDocumentPosition(pivot) & 4) { total += n.nodeValue.length; }
                else                                       { return total; }
            }
        }
    }
    return total;
}

function resolveTextOffset(target) {
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
    var total = 0, n;
    while ((n = walker.nextNode())) {
        var len = n.nodeValue.length;
        if (total + len >= target) return { node: n, offset: target - total };
        total += len;
    }
    return null;
}

// ── Scroll tracking ──────────────────────────────────────────────────────────
window.addEventListener('scroll', function() {
    var h = document.body.scrollHeight - window.innerHeight;
    var pct = h > 0 ? window.scrollY / h : 0;
    try { window.webkit.messageHandlers.scrollHandler.postMessage(Math.min(1, Math.max(0, pct))); } catch(e) {}
});

// ── Text selection → Swift ───────────────────────────────────────────────────
function checkSelection() {
    var sel = window.getSelection();
    if (!sel || sel.isCollapsed) return;
    var text = sel.toString().trim();
    if (text.length < 2) return;
    var range = sel.getRangeAt(0);
    var start = bodyTextLength(range.startContainer, range.startOffset);
    var end   = bodyTextLength(range.endContainer,   range.endOffset);
    if (start < 0 || end <= start) return;
    try {
        window.webkit.messageHandlers.selectionHandler.postMessage(
            JSON.stringify({ text: text, start: start, end: end })
        );
    } catch(e) {}
}
document.addEventListener('mouseup', checkSelection);
document.addEventListener('touchend', function() { setTimeout(checkSelection, 150); });

// ── Highlight rendering ──────────────────────────────────────────────────────
window.applyHighlight = function(locStr, color) {
    var data; try { data = JSON.parse(locStr); } catch(e) { return; }
    if (data.start == null || data.end == null) return;
    var s = resolveTextOffset(data.start);
    var e = resolveTextOffset(data.end);
    if (!s || !e) return;

    var hlColors = { yellow: '#F2D578', green: '#ADD8B0', blue: '#A9CCEA', pink: '#E6B6C4' };
    var bgColor = hlColors[color] || '#F2D578';

    function wrapTextNode(tn, from, to) {
        from = Math.max(0, from);
        to   = Math.min(tn.nodeValue.length, to);
        if (from >= to) return;
        var mid = tn.splitText(from);
        if (to - from < mid.nodeValue.length) mid.splitText(to - from);
        var span = document.createElement('span');
        span.className = 'hl-' + color;
        span.dataset.hlLoc = locStr;
        span.style.backgroundColor = bgColor;
        span.style.borderRadius = '3px';
        mid.parentNode.insertBefore(span, mid);
        span.appendChild(mid);
    }

    if (s.node === e.node) {
        wrapTextNode(s.node, s.offset, e.offset);
        return;
    }

    var nodes = [];
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
    var found = false, n;
    while ((n = walker.nextNode())) {
        if (n === s.node) found = true;
        if (found) nodes.push(n);
        if (n === e.node) break;
    }
    nodes.forEach(function(tn) {
        wrapTextNode(tn, tn === s.node ? s.offset : 0, tn === e.node ? e.offset : tn.nodeValue.length);
    });
};

window.clearHighlights = function() {
    var spans;
    while ((spans = document.querySelectorAll('[data-hl-loc]')).length) {
        spans.forEach(function(span) {
            var p = span.parentNode; if (!p) return;
            while (span.firstChild) p.insertBefore(span.firstChild, span);
            p.removeChild(span);
        });
    }
    document.body.normalize();
};

window.loadHighlights = function(hs) {
    window.clearHighlights();
    window.clearSelection();
    if (!Array.isArray(hs)) return;
    hs.forEach(function(h) { window.applyHighlight(h.loc, h.color); });
};

window.clearSelection = function() {
    if (window.getSelection) window.getSelection().removeAllRanges();
};
"""
