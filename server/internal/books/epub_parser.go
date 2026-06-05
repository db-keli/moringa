package books

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/PuerkitoBio/goquery"
)

type Chunk struct {
	Index   int    `json:"index"`
	Title   string `json:"title"`
	Content string `json:"html"`
	Path    string `json:"path"` // spine item path inside the EPUB (e.g. OEBPS/Text/ch01.xhtml)
}

func ParseEPUB(epubPath, outputDir, bookID, baseURL string) ([]Chunk, error) {
	r, err := zip.OpenReader(epubPath)
	if err != nil {
		return nil, fmt.Errorf("open epub: %w", err)
	}
	defer r.Close()

	files := r.File
	opfPath, err := findOPF(files)
	if err != nil {
		return nil, err
	}

	opfDir := filepath.Dir(opfPath)
	opfRaw, err := readFile(files, opfPath)
	if err != nil {
		return nil, fmt.Errorf("read opf: %w", err)
	}

	pkg, err := parseOPF(opfRaw)
	if err != nil {
		return nil, fmt.Errorf("parse opf: %w", err)
	}

	spineItems := resolveSpine(pkg, opfDir)
	assetBase := strings.TrimRight(baseURL, "/") + "/books/" + bookID + "/assets"

	var chunks []Chunk
	for i, item := range spineItems {
		raw, err := readFile(files, item.path)
		if err != nil {
			chunks = append(chunks, Chunk{Index: i, Title: fmt.Sprintf("Chapter %d", i+1)})
			continue
		}
		title, html := buildChunk(raw, files, item.path, assetBase)
		chunks = append(chunks, Chunk{Index: i, Title: title, Content: html, Path: item.path})
	}

	for _, f := range files {
		if f.FileInfo().IsDir() {
			continue
		}
		dest := filepath.Join(outputDir, f.Name)
		if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			continue
		}
		out, err := os.Create(dest)
		if err != nil {
			rc.Close()
			continue
		}
		io.Copy(out, rc) //nolint:errcheck
		rc.Close()
		out.Close()
	}

	b, err := json.Marshal(chunks)
	if err != nil {
		return nil, fmt.Errorf("marshal chunks: %w", err)
	}
	if err := os.WriteFile(filepath.Join(outputDir, "chunks.json"), b, 0o644); err != nil {
		return nil, fmt.Errorf("write chunks.json: %w", err)
	}
	return chunks, nil
}

// buildChunk produces a self-contained HTML fragment for one spine item.
// It embeds the chapter's CSS (inline <style> blocks and linked .css files,
// with @font-face / url() rewritten to absolute server URLs) and rewrites
// all asset src/href values, so the WebView needs no base URL.
func buildChunk(raw []byte, files []*zip.File, chapterPath, assetBase string) (title, html string) {
	chapterDir := filepath.ToSlash(filepath.Dir(chapterPath))
	if chapterDir == "." {
		chapterDir = ""
	}

	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(raw))
	if err != nil {
		return titleFromHref(chapterPath), strings.TrimSpace(string(raw))
	}

	title = strings.TrimSpace(doc.Find("title").First().Text())
	if title == "" {
		title = titleFromHref(chapterPath)
	}

	var cssBlocks []string

	doc.Find("head style").Each(func(_ int, s *goquery.Selection) {
		if text := strings.TrimSpace(s.Text()); text != "" {
			cssBlocks = append(cssBlocks, text)
		}
	})

	doc.Find("head link").Each(func(_ int, s *goquery.Selection) {
		rel, _ := s.Attr("rel")
		if !strings.EqualFold(strings.TrimSpace(rel), "stylesheet") {
			return
		}
		href, _ := s.Attr("href")
		if href == "" {
			return
		}
		cssPath := href
		if chapterDir != "" {
			cssPath = filepath.ToSlash(filepath.Join(chapterDir, href))
		}
		cssPath = strings.TrimPrefix(cssPath, "./")
		cssRaw, err := readFile(files, cssPath)
		if err != nil {
			return
		}
		cssDir := filepath.ToSlash(filepath.Dir(cssPath))
		if cssDir == "." {
			cssDir = ""
		}
		cssBlocks = append(cssBlocks, rewriteCSSURLs(string(cssRaw), cssDir, assetBase))
	})

	isAbsolute := func(v string) bool {
		return strings.HasPrefix(v, "http://") || strings.HasPrefix(v, "https://") ||
			strings.HasPrefix(v, "data:") || strings.HasPrefix(v, "#")
	}
	resolve := func(val string) string {
		p := val
		if chapterDir != "" {
			p = filepath.ToSlash(filepath.Join(chapterDir, val))
		}
		return strings.TrimPrefix(p, "./")
	}

	doc.Find("body [src]").Each(func(_ int, s *goquery.Selection) {
		if v, _ := s.Attr("src"); v != "" && !isAbsolute(v) {
			s.SetAttr("src", assetBase+"/"+resolve(v))
		}
	})
	doc.Find("body [href]").Each(func(_ int, s *goquery.Selection) {
		if v, _ := s.Attr("href"); v != "" && !isAbsolute(v) {
			s.SetAttr("href", assetBase+"/"+resolve(v))
		}
	})
	doc.Find("body [xlink\\:href]").Each(func(_ int, s *goquery.Selection) {
		if v, _ := s.Attr("xlink:href"); v != "" && !isAbsolute(v) {
			s.SetAttr("xlink:href", assetBase+"/"+resolve(v))
		}
	})

	bodyHTML, err := doc.Find("body").Html()
	if err != nil || strings.TrimSpace(bodyHTML) == "" {
		return title, strings.TrimSpace(string(raw))
	}

	var sb strings.Builder
	if len(cssBlocks) > 0 {
		sb.WriteString("<style>\n")
		for _, css := range cssBlocks {
			sb.WriteString(css)
			sb.WriteByte('\n')
		}
		sb.WriteString("</style>\n")
	}
	sb.WriteString(strings.TrimSpace(bodyHTML))
	return title, sb.String()
}

func rewriteCSSURLs(css, cssDir, assetBase string) string {
	re := regexp.MustCompile(`url\(\s*['"]?([^'")#\s][^'")\s]*?)['"]?\s*\)`)
	return re.ReplaceAllStringFunc(css, func(match string) string {
		m := re.FindStringSubmatch(match)
		if len(m) < 2 {
			return match
		}
		val := m[1]
		if strings.HasPrefix(val, "http://") || strings.HasPrefix(val, "https://") ||
			strings.HasPrefix(val, "data:") {
			return match
		}
		p := val
		if cssDir != "" {
			p = filepath.ToSlash(filepath.Join(cssDir, val))
		}
		p = strings.TrimPrefix(p, "./")
		return "url('" + assetBase + "/" + p + "')"
	})
}

func titleFromHref(href string) string {
	base := filepath.Base(href)
	base = strings.TrimSuffix(base, filepath.Ext(base))
	base = strings.NewReplacer("_", " ", "-", " ").Replace(base)
	if len(base) > 0 {
		base = strings.ToUpper(base[:1]) + base[1:]
	}
	return base
}

type opfPackage struct {
	Metadata struct {
		Title   string `xml:"title"`
		Creator string `xml:"creator"`
	} `xml:"metadata"`
	Manifest struct {
		Items []struct {
			ID        string `xml:"id,attr"`
			Href      string `xml:"href,attr"`
			MediaType string `xml:"media-type,attr"`
		} `xml:"item"`
	} `xml:"manifest"`
	Spine struct {
		Items []struct {
			IDRef string `xml:"idref,attr"`
		} `xml:"itemref"`
	} `xml:"spine"`
}

func findOPF(files []*zip.File) (string, error) {
	containerRaw, err := readFile(files, "META-INF/container.xml")
	if err != nil {
		containerRaw, err = readFile(files, "meta-inf/container.xml")
		if err != nil {
			return "", fmt.Errorf("META-INF/container.xml not found")
		}
	}

	type containerRoot struct {
		Rootfiles struct {
			Rootfile []struct {
				FullPath string `xml:"full-path,attr"`
			} `xml:"rootfile"`
		} `xml:"rootfiles"`
	}

	cleaned := stripXMLNS(containerRaw)
	var cr containerRoot
	if err := decodeXML(cleaned, &cr); err != nil {
		return "", fmt.Errorf("parse container.xml: %w", err)
	}
	if len(cr.Rootfiles.Rootfile) == 0 {
		return "", fmt.Errorf("no rootfile in container.xml")
	}
	return cr.Rootfiles.Rootfile[0].FullPath, nil
}

func parseOPF(raw []byte) (*opfPackage, error) {
	cleaned := stripXMLNS(raw)
	var pkg opfPackage
	if err := decodeXML(cleaned, &pkg); err != nil {
		return nil, err
	}
	return &pkg, nil
}

type spineItem struct {
	path string
	href string
}

func resolveSpine(pkg *opfPackage, opfDir string) []spineItem {
	manifest := make(map[string]struct {
		href      string
		mediaType string
	}, len(pkg.Manifest.Items))
	for _, it := range pkg.Manifest.Items {
		manifest[it.ID] = struct {
			href      string
			mediaType string
		}{href: it.Href, mediaType: it.MediaType}
	}

	var items []spineItem
	for _, sr := range pkg.Spine.Items {
		entry, ok := manifest[sr.IDRef]
		if !ok {
			continue
		}
		if !isContentType(entry.mediaType) {
			continue
		}
		path := filepath.ToSlash(filepath.Join(opfDir, entry.href))
		items = append(items, spineItem{path: path, href: entry.href})
	}
	return items
}

func isContentType(mt string) bool {
	mt = strings.ToLower(mt)
	return mt == "application/xhtml+xml" ||
		mt == "text/html" ||
		mt == "application/xml" ||
		mt == "text/xml"
}

func readFile(files []*zip.File, name string) ([]byte, error) {
	name = filepath.ToSlash(strings.ToLower(strings.TrimPrefix(name, "./")))
	for _, f := range files {
		if filepath.ToSlash(strings.ToLower(f.Name)) == name {
			rc, err := f.Open()
			if err != nil {
				return nil, err
			}
			defer rc.Close()
			return io.ReadAll(rc)
		}
	}
	return nil, fmt.Errorf("file not found in epub: %s", name)
}

func stripXMLNS(raw []byte) []byte {
	re := regexp.MustCompile(`\s+xmlns(?::\w+)?="[^"]+"`)
	cleaned := re.ReplaceAll(raw, []byte{})
	re2 := regexp.MustCompile(`</(\w+):`)
	cleaned = re2.ReplaceAll(cleaned, []byte("</"))
	re3 := regexp.MustCompile(`<(\w+):`)
	cleaned = re3.ReplaceAll(cleaned, []byte("<"))
	return cleaned
}

func decodeXML(raw []byte, v any) error {
	dec := xml.NewDecoder(bytes.NewReader(raw))
	dec.Strict = false
	dec.Entity = xml.HTMLEntity
	return dec.Decode(v)
}
