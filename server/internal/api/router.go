package api

import (
	"net/http"

	"github.com/kekelidompeh/moringa/internal/store"
	msync "github.com/kekelidompeh/moringa/internal/sync"
)

type Handler struct {
	store    *store.Store
	broker   *msync.Broker
	booksDir string
}

func NewHandler(s *store.Store, b *msync.Broker, booksDir string) *Handler {
	return &Handler{store: s, broker: b, booksDir: booksDir}
}

func NewRouter(h *Handler, authToken string) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	mux.HandleFunc("GET /books", h.listBooks)
	mux.HandleFunc("GET /books/{id}", h.getBook)
	mux.HandleFunc("GET /books/{id}/chunks", h.getBookChunks)
	mux.HandleFunc("POST /books/import", h.importBook)

	mux.HandleFunc("POST /events", h.ingestEvent)
	mux.HandleFunc("GET /stream", h.stream)

	return jsonHeader(auth(authToken, mux))
}
