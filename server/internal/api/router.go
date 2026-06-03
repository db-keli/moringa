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

// Health returns a simple health check.
// @Summary Health check
// @Description Returns {"status": "ok"} if the server is running.
// @Tags system
// @Produce json
// @Success 200 {object} map[string]string
// @Router /health [get]
func (h *Handler) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func NewRouter(h *Handler, authToken string) http.Handler {
	mux := http.NewServeMux()

	// Public routes (no auth required)
	mux.HandleFunc("GET /health", h.health)
	mux.HandleFunc("GET /swagger/doc.json", SwaggerJSON)
	mux.HandleFunc("GET /swagger/", SwaggerUI)

	// Protected routes
	protected := http.NewServeMux()
	protected.HandleFunc("GET /books", h.listBooks)
	protected.HandleFunc("GET /books/{id}", h.getBook)
	protected.HandleFunc("GET /books/{id}/chunks", h.getBookChunks)
	protected.Handle("GET /books/{id}/assets/", h.bookAssets())
	protected.HandleFunc("POST /books/import", h.importBook)
	protected.HandleFunc("POST /events", h.ingestEvent)
	protected.HandleFunc("GET /stream", h.stream)

	mux.Handle("/", auth(authToken, protected))

	return jsonHeader(mux)
}
