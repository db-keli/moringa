package api

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/jackc/pgx/v5"
	"github.com/kekelidompeh/moringa/internal/store"
)

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

// getBookChunks serves the pre-parsed chapter chunks from disk.
// Clients cache this permanently — it is only called once per book per device.
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

// importBook accepts an EPUB upload, stores it on disk, and records the metadata.
// EPUB parsing into chunks happens asynchronously after the upload.
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

	file, _, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, "file is required")
		return
	}
	defer file.Close()

	book, err := h.store.InsertBook(r.Context(), title, author, "")
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to create book")
		return
	}

	bookDir := filepath.Join(h.booksDir, book.ID)
	if err := os.MkdirAll(bookDir, 0o755); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to create storage directory")
		return
	}

	destPath := filepath.Join(bookDir, "original.epub")
	dest, err := os.Create(destPath)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to save file")
		return
	}
	defer dest.Close()

	if _, err := io.Copy(dest, file); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to write file")
		return
	}

	// TODO: enqueue async EPUB parse → write chunks.json
	fmt.Printf("book %s uploaded, parse not yet implemented\n", book.ID)

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
