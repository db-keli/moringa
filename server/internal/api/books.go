package api

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/kekelidompeh/moringa/internal/books"
	"github.com/kekelidompeh/moringa/internal/store"
)

// ListBooks returns all books.
// @Summary List all books
// @Description Returns all imported books with metadata.
// @Tags books
// @Produce json
// @Success 200 {array} store.Book
// @Failure 500 {object} map[string]string
// @Router /books [get]
// @Security BearerAuth
func (h *Handler) listBooks(w http.ResponseWriter, r *http.Request) {
	books, err := h.store.ListBooks(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list books")
		return
	}
	if books == nil {
		books = []store.Book{}
	}
	writeJSON(w, http.StatusOK, books)
}

// GetBook returns a single book by ID.
// @Summary Get a book
// @Description Returns book metadata for the given ID.
// @Tags books
// @Produce json
// @Param id path string true "Book ID"
// @Success 200 {object} store.Book
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /books/{id} [get]
// @Security BearerAuth
func (h *Handler) getBook(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	book, err := h.store.GetBook(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "book not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to get book")
		return
	}
	writeJSON(w, http.StatusOK, book)
}

// GetBookChunks serves the pre-parsed chapter chunks from disk.
// Clients cache this permanently — it is only called once per book per device.
// @Summary Get book chunks
// @Description Returns pre-parsed chapter chunks for a book. Clients cache this permanently.
// @Tags books
// @Produce json
// @Param id path string true "Book ID"
// @Success 200 {array} map[string]any
// @Failure 404 {object} map[string]string
// @Router /books/{id}/chunks [get]
// @Security BearerAuth
func (h *Handler) getBookChunks(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")

	_, err := h.store.GetBook(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, "book not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to get book")
		return
	}

	chunksPath := filepath.Join(h.booksDir, id, "chunks.json")
	f, err := os.Open(chunksPath)
	if err != nil {
		writeError(w, http.StatusNotFound, "chunks not found")
		return
	}
	defer f.Close()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	io.Copy(w, f) //nolint:errcheck
}

// ImportBook accepts an EPUB upload, stores it on disk, and records the metadata.
// EPUB parsing into chunks happens asynchronously after the upload.
// @Summary Import an EPUB
// @Description Upload an EPUB file. The server stores it on disk and records metadata. EPUB parsing (chunk extraction) runs asynchronously after upload.
// @Tags books
// @Accept multipart/form-data
// @Produce json
// @Param title formData string true "Book title"
// @Param author formData string false "Book author"
// @Param file formData file true "EPUB file"
// @Success 201 {object} store.Book
// @Failure 400 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /books/import [post]
// @Security BearerAuth
func (h *Handler) importBook(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(128 << 20); err != nil {
		writeError(w, http.StatusBadRequest, "invalid multipart form")
		return
	}

	title := r.FormValue("title")
	author := r.FormValue("author")
	if title == "" {
		writeError(w, http.StatusBadRequest, "title is required")
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, "file is required")
		return
	}
	defer file.Close()

	if !strings.HasSuffix(strings.ToLower(header.Filename), ".epub") {
		writeError(w, http.StatusBadRequest, "only .epub files are accepted")
		return
	}

	magic := make([]byte, 4)
	if _, err := io.ReadFull(file, magic); err != nil {
		writeError(w, http.StatusBadRequest, "invalid file")
		return
	}
	if magic[0] != 0x50 || magic[1] != 0x4B || magic[2] != 0x03 || magic[3] != 0x04 {
		writeError(w, http.StatusBadRequest, "file is not a valid EPUB (ZIP) archive")
		return
	}

	// Save the uploaded EPUB to a temp location, then insert the book
	// record to get the ID, and finally move it into place.
	if err := os.MkdirAll(h.booksDir, 0o755); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to create books directory")
		return
	}
	tmp, err := os.CreateTemp(h.booksDir, "upload-*")
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to save file")
		return
	}
	tmpPath := tmp.Name()
	if _, err := tmp.Write(magic); err != nil {
		os.Remove(tmpPath)
		writeError(w, http.StatusInternalServerError, "failed to write file")
		return
	}
	if _, err := io.Copy(tmp, file); err != nil {
		os.Remove(tmpPath)
		writeError(w, http.StatusInternalServerError, "failed to write file")
		return
	}
	tmp.Close()

	book, err := h.store.InsertBook(r.Context(), title, author, "")
	if err != nil {
		os.Remove(tmpPath)
		writeError(w, http.StatusInternalServerError, "failed to create book")
		return
	}

	bookDir := filepath.Join(h.booksDir, book.ID)
	if err := os.MkdirAll(bookDir, 0o755); err != nil {
		os.Remove(tmpPath)
		writeError(w, http.StatusInternalServerError, "failed to create storage directory")
		return
	}
	destPath := filepath.Join(bookDir, "original.epub")
	if err := os.Rename(tmpPath, destPath); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to finalize file")
		return
	}

	// Parse EPUB into chunks (best-effort, non-fatal on failure).
	if _, err := books.ParseEPUB(destPath, bookDir); err != nil {
		log.Printf("error parsing epub %s: %v", book.ID, err)
	}

	writeJSON(w, http.StatusCreated, book)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v) //nolint:errcheck
}

func writeError(w http.ResponseWriter, status int, msg string) {
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": msg}) //nolint:errcheck
}
