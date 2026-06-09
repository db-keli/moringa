import SwiftUI
import WebKit

// MARK: - WKWebView wrapper (iOS)

struct WebReaderView: UIViewRepresentable {
    let chapterURL: URL?
    let html: String
    let isDark: Bool
    let fontSize: Double
    var readingLayout: ReadingLayout = .scroll
    var highlights: [Highlight] = []
    var onScrollPct: ((Double) -> Void)?
    var onTextSelected: ((String) -> Void)?
    var onChapterLink: ((String) -> Void)?
    var onPageInfo: ((Int, Int) -> Void)?     // (currentPage, totalPages)

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let uc = config.userContentController
        uc.add(context.coordinator, name: "scrollHandler")
        uc.add(context.coordinator, name: "selectionHandler")
        uc.add(context.coordinator, name: "pageInfoHandler")
        uc.addUserScript(WKUserScript(
            source: staticLayoutCSS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        uc.addUserScript(WKUserScript(
            source: readerJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.backgroundColor = .clear
        wv.isOpaque = false
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        // WebKit handles pinch-to-zoom natively via the viewport meta (initial-scale=1 without
        // user-scalable=no). Setting UIScrollView zoom scales here would override WebKit's own
        // zoom and cause them to fight each other — so we leave them at their defaults.
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        let c = context.coordinator
        c.onScrollPct    = onScrollPct
        c.onTextSelected = onTextSelected
        c.onChapterLink  = onChapterLink
        c.onPageInfo     = onPageInfo
        c.webView        = wv
        c.isDark         = isDark
        c.fontSize       = fontSize
        c.readingLayout  = readingLayout
        c.highlights     = highlights

        let urlChanged   = c.loadedURL  != chapterURL
        let htmlChanged  = c.loadedHTML != html
        let styleChanged = c.loadedIsDark != isDark || c.loadedFontSize != fontSize || c.loadedLayout != readingLayout

        if urlChanged || (chapterURL == nil && htmlChanged) {
            c.loadedURL  = chapterURL
            c.loadedHTML = html
            if let url = chapterURL {
                wv.load(URLRequest(url: url))
            } else {
                wv.loadHTMLString(offlineShell(html), baseURL: nil)
            }
        } else if styleChanged {
            c.loadedIsDark   = isDark
            c.loadedFontSize = fontSize
            c.loadedLayout   = readingLayout
            c.injectCSS(into: wv)
        } else {
            c.injectHighlights(into: wv)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onScrollPct: ((Double) -> Void)?
        var onTextSelected: ((String) -> Void)?
        var onChapterLink: ((String) -> Void)?
        var onPageInfo: ((Int, Int) -> Void)?
        var highlights: [Highlight] = []
        weak var webView: WKWebView?

        var isDark: Bool         = false
        var fontSize: Double     = 18
        var readingLayout: ReadingLayout = .scroll

        var loadedURL: URL?        = nil
        var loadedHTML: String     = ""
        var loadedIsDark: Bool     = false
        var loadedFontSize: Double = 0
        var loadedLayout: ReadingLayout = .scroll

        func userContentController(_ ctrl: WKUserContentController, didReceive msg: WKScriptMessage) {
            switch msg.name {
            case "scrollHandler":
                if let pct = msg.body as? Double { onScrollPct?(pct) }
            case "selectionHandler":
                if let text = msg.body as? String, !text.isEmpty { onTextSelected?(text) }
            case "pageInfoHandler":
                if let d = msg.body as? [String: Any],
                   let cur = d["current"] as? Int,
                   let tot = d["total"] as? Int {
                    onPageInfo?(cur, tot)
                }
            default: break
            }
        }

        func webView(_ wv: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard action.navigationType == .linkActivated,
                  let url = action.request.url else {
                decisionHandler(.allow)
                return
            }
            let ext = url.pathExtension.lowercased()
            if ext == "xhtml" || ext == "html" || ext == "htm" || ext.isEmpty {
                onChapterLink?(url.lastPathComponent)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loadedIsDark   = isDark
            loadedFontSize = fontSize
            loadedLayout   = readingLayout
            injectCSS(into: webView)
            injectHighlights(into: webView)
        }

        // MARK: CSS + page tracking injection

        func injectCSS(into wv: WKWebView) {
            let bg        = isDark ? "#161B1C" : "#FFFFFF"
            let ink       = isDark ? "#EAE7DE" : ""
            let colorRule = isDark ? "color: \(ink) !important;" : ""

            let layoutRule: String
            let pageJS: String

            switch readingLayout {
            case .scroll:
                wv.scrollView.isPagingEnabled        = false
                wv.scrollView.alwaysBounceVertical   = true
                wv.scrollView.alwaysBounceHorizontal = false
                layoutRule = """
                    html { height: auto !important; overflow: visible !important; }
                    body {
                        max-width: 100% !important;
                        margin: 0 !important;
                        padding: 20px 14px 80px !important;
                        column-count: unset !important;
                        height: auto !important; overflow: visible !important;
                    }
                """
                pageJS = """
                    (function() {
                        if (window._moringaPageListener) {
                            window.removeEventListener('scroll', window._moringaPageListener);
                        }
                        window._moringaPageListener = function() {
                            var ph = window.innerHeight;
                            var total = Math.max(1, Math.ceil(document.body.scrollHeight / ph));
                            var current = Math.min(total, Math.floor(window.scrollY / ph) + 1);
                            try { window.webkit.messageHandlers.pageInfoHandler.postMessage({current: current, total: total}); } catch(e) {}
                        };
                        window.addEventListener('scroll', window._moringaPageListener);
                        setTimeout(window._moringaPageListener, 150);
                    })();
                """

            case .paginated:
                // Columns on :root (same as Readium). Content overflows :root to the right;
                // WebKit sets scrollView.contentSize.width = all columns width.
                // isPagingEnabled snaps each swipe to exactly one viewport width = one page.
                wv.scrollView.isPagingEnabled              = true
                wv.scrollView.alwaysBounceVertical         = false
                wv.scrollView.alwaysBounceHorizontal       = true
                wv.scrollView.showsVerticalScrollIndicator = false
                wv.scrollView.showsHorizontalScrollIndicator = false
                layoutRule = """
                    :root {
                        height: 100vh !important;
                        max-height: 100vh !important;
                        column-count: 1 !important;
                        column-fill: auto !important;
                        column-gap: 0 !important;
                        padding: 48px 48px !important;
                        box-sizing: border-box !important;
                    }
                    body {
                        max-width: unset !important;
                        margin: 0 !important;
                        padding: 0 !important;
                        height: auto !important;
                    }
                """
                pageJS = paginatedPageTrackingJS(cols: 1)

            case .twoColumn:
                // Two columns per spread. Virtual blank column inserted when total is odd
                // so every spread always shows a full pair (same trick as Readium).
                wv.scrollView.isPagingEnabled              = true
                wv.scrollView.alwaysBounceVertical         = false
                wv.scrollView.alwaysBounceHorizontal       = true
                wv.scrollView.showsVerticalScrollIndicator = false
                wv.scrollView.showsHorizontalScrollIndicator = false
                layoutRule = """
                    :root {
                        height: 100vh !important;
                        max-height: 100vh !important;
                        column-count: 2 !important;
                        column-fill: auto !important;
                        column-gap: 32px !important;
                        column-rule: 1px solid rgba(128,128,128,0.18) !important;
                        padding: 48px 32px !important;
                        box-sizing: border-box !important;
                    }
                    body {
                        max-width: unset !important;
                        margin: 0 !important;
                        padding: 0 !important;
                        height: auto !important;
                    }
                """
                pageJS = paginatedPageTrackingJS(cols: 2)
            }

            let css = """
                html { font-size: \(fontSize)px !important; }
                body { font-size: \(fontSize)px !important; }
                html, body { background: \(bg) !important; \(colorRule) }
                \(layoutRule)
                img { max-width: 100% !important; width: auto !important; height: auto !important; }
                figure { max-width: 100% !important; }
                table { max-width: 100% !important; overflow-x: auto; display: block; }
                p, li, td, th, blockquote { word-wrap: break-word; overflow-wrap: break-word; }
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
                \(pageJS)
            """, completionHandler: nil)
        }

        func injectHighlights(into wv: WKWebView) {
            let hlData = highlights.map { ["loc": $0.loc, "color": $0.color.rawValue] }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: hlData),
                  let json = String(data: jsonData, encoding: .utf8) else { return }
            wv.evaluateJavaScript("window.loadHighlights(\(json))", completionHandler: nil)
        }
    }
}

// MARK: - Offline shell

private func offlineShell(_ html: String) -> String {
    let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("<!DOCTYPE") || trimmed.lowercased().hasPrefix("<html") {
        return html
    }
    return """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    </head>
    <body>
    \(html)
    </body>
    </html>
    """
}

// MARK: - Paginated page-tracking JS

/// Shared JS injected after CSS for both paginated and two-column modes.
/// - Snaps scroll to the nearest column boundary (guards against fractional offsets).
/// - Ensures an even total number of spread-columns for two-column mode.
/// - Reports current/total page count via pageInfoHandler.
private func paginatedPageTrackingJS(cols: Int) -> String {
    """
    (function() {
        window.scrollTo(0, 0);

        // Snap to nearest column boundary (Readium's snapCurrentPosition)
        function snapToPage() {
            var w = window.innerWidth;
            var x = window.scrollX;
            var snapped = Math.round(x / w) * w;
            if (Math.abs(x - snapped) > 1) {
                document.scrollingElement.scrollLeft = snapped;
            }
        }

        \(cols == 2 ? """
        // Append a virtual blank column when total spread count is odd
        // so the last spread always shows a full pair (Readium technique).
        function ensureEvenSpreads() {
            var w = window.innerWidth;
            var totalW = document.scrollingElement.scrollWidth;
            var numSpreads = Math.round(totalW / w);
            var existing = document.getElementById('moringa-virtual-col');
            if (numSpreads % 2 !== 0) {
                if (!existing) {
                    var div = document.createElement('div');
                    div.id = 'moringa-virtual-col';
                    div.style.breakBefore = 'column';
                    div.innerHTML = '\\u200B';
                    document.body.appendChild(div);
                }
            } else {
                existing && existing.remove();
            }
        }
        setTimeout(ensureEvenSpreads, 200);
        """ : "")

        if (window._moringaPageListener) {
            window.removeEventListener('scroll', window._moringaPageListener);
        }
        window._moringaPageListener = function() {
            snapToPage();
            var w = window.innerWidth;
            var total = Math.max(1, Math.round(document.scrollingElement.scrollWidth / w));
            var current = Math.round(window.scrollX / w) + 1;
            try { window.webkit.messageHandlers.pageInfoHandler.postMessage({current: current, total: total}); } catch(e) {}
        };
        window.addEventListener('scroll', window._moringaPageListener);
        setTimeout(function() {
            var w = window.innerWidth;
            var total = Math.max(1, Math.round(document.scrollingElement.scrollWidth / w));
            try { window.webkit.messageHandlers.pageInfoHandler.postMessage({current: 1, total: total}); } catch(e) {}
        }, 350);
    })();
    """
}

// MARK: - Static layout CSS (injected at document start to prevent FOUC)

private let staticLayoutCSS = """
(function() {
    var s = document.createElement('style');
    s.id = 'moringa-layout';
    s.textContent = `
        *, *::before, *::after { box-sizing: border-box; }
        html { -webkit-text-size-adjust: 100%; -webkit-font-smoothing: antialiased; }
        body {
            max-width: 720px;
            margin-left: auto;
            margin-right: auto;
            padding: 24px 20px 100px;
        }
        img { max-width: 100%; width: auto; height: auto; }
        figure { max-width: 100%; }
        video, audio, iframe, canvas { max-width: 100%; height: auto; }
        table { max-width: 100%; overflow-x: auto; display: block; }
        p, li, td, th, blockquote { word-wrap: break-word; overflow-wrap: break-word; }
        .hl-yellow { background: #F2D578; border-radius: 3px; padding: 1px 0; }
        .hl-green  { background: #ADD8B0; border-radius: 3px; padding: 1px 0; }
        .hl-blue   { background: #A9CCEA; border-radius: 3px; padding: 1px 0; }
        .hl-pink   { background: #E6B6C4; border-radius: 3px; padding: 1px 0; }
    `;
    (document.head || document.documentElement).appendChild(s);
})();
"""

// MARK: - Reader JS

private let readerJS = """
function bodyTextLength(container, offset) {
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
    var total = 0, n;
    while ((n = walker.nextNode())) {
        if (container.nodeType === Node.TEXT_NODE) {
            if (n === container) return total + offset;
            total += n.nodeValue.length;
        } else {
            var pivot = container.childNodes[offset] || null;
            if (pivot === null) {
                if (container.contains(n)) { total += n.nodeValue.length; }
                else                        { return total; }
            } else {
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

window.addEventListener('scroll', function() {
    var h = document.body.scrollHeight - window.innerHeight;
    var pct = h > 0 ? window.scrollY / h : 0;
    try { window.webkit.messageHandlers.scrollHandler.postMessage(Math.min(1, Math.max(0, pct))); } catch(e) {}
});

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
