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
)

type Chunk struct {
	Index   int    `json:"index"`
	Title   string `json:"title"`
	Content string `json:"content"`
}

func ParseEPUB(epubPath, outputDir string) ([]Chunk, error) {
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

	var chunks []Chunk
	for i, item := range spineItems {
		raw, err := readFile(files, item.path)
		if err != nil {
			chunks = append(chunks, Chunk{
				Index:   i,
				Title:   fmt.Sprintf("Chapter %d", i+1),
				Content: "",
			})
			continue
		}

		title := extractTitle(raw, item.href)
		body := extractBody(raw)
		chunks = append(chunks, Chunk{
			Index:   i,
			Title:   title,
			Content: body,
		})
	}

	for _, f := range files {
		if f.FileInfo().IsDir() {
			continue
		}
		ext := strings.ToLower(filepath.Ext(f.Name))
		if ext == ".xhtml" || ext == ".html" || ext == ".htm" || ext == ".xml" || ext == ".opf" ||
			ext == ".ncx" {
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
	})
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
		path := filepath.Join(opfDir, entry.href)
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

func extractTitle(raw []byte, href string) string {
	// Try XHTML <title> tag.
	re := regexp.MustCompile(`(?is)<title[^>]*>(.*?)</title>`)
	if m := re.FindSubmatch(raw); len(m) > 1 {
		t := strings.TrimSpace(string(m[1]))
		if t != "" {
			return t
		}
	}

	// Fall back to filename without extension.
	base := filepath.Base(href)
	base = strings.TrimSuffix(base, filepath.Ext(base))
	base = strings.ReplaceAll(base, "_", " ")
	base = strings.ReplaceAll(base, "-", " ")
	if len(base) > 0 {
		base = strings.ToUpper(base[:1]) + base[1:]
	}
	return base
}

func extractBody(raw []byte) string {
	re := regexp.MustCompile(`(?is)<body[^>]*>(.*)</body>`)
	if m := re.FindSubmatch(raw); len(m) > 1 {
		return strings.TrimSpace(string(m[1]))
	}
	return ""
}

func readFile(files []*zip.File, name string) ([]byte, error) {
	for _, f := range files {
		normalized := filepath.ToSlash(strings.ToLower(f.Name))
		target := filepath.ToSlash(strings.ToLower(name))
		if normalized == target {
			rc, err := f.Open()
			if err != nil {
				return nil, err
			}
			defer rc.Close()
			return io.ReadAll(rc)
		}
	}
	return nil, fmt.Errorf("file not found: %s", name)
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
