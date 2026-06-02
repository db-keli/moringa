package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/joho/godotenv"
	"github.com/kekelidompeh/moringa/internal/api"
	"github.com/kekelidompeh/moringa/internal/config"
	"github.com/kekelidompeh/moringa/internal/store"
	msync "github.com/kekelidompeh/moringa/internal/sync"
)

func main() {
	_ = godotenv.Load()

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	ctx := context.Background()

	db, err := store.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("database: %v", err)
	}
	defer db.Close()
	log.Println("database connected")

	if err := os.MkdirAll(cfg.BooksDir, 0o755); err != nil {
		log.Fatalf("books dir: %v", err)
	}

	s := store.New(db)
	broker := msync.NewBroker()
	handler := api.NewHandler(s, broker, cfg.BooksDir)
	router := api.NewRouter(handler, cfg.AuthToken)

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.Port),
		Handler:      router,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 0, // SSE streams are long-lived
		IdleTimeout:  120 * time.Second,
	}

	log.Printf("moringa listening on :%s", cfg.Port)
	if err := srv.ListenAndServe(); err != nil {
		log.Fatalf("server: %v", err)
	}
}
