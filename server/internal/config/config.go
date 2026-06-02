package config

import (
	"fmt"
	"os"
)

type Config struct {
	Port        string
	DatabaseURL string
	BooksDir    string
	AuthToken   string
}

func Load() (*Config, error) {
	db := os.Getenv("DATABASE_URL")
	if db == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}

	authToken := os.Getenv("AUTH_TOKEN")
	if authToken == "" {
		return nil, fmt.Errorf("AUTH_TOKEN is required")
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	booksDir := os.Getenv("BOOKS_DIR")
	if booksDir == "" {
		booksDir = "./data/books"
	}

	return &Config{
		Port:        port,
		DatabaseURL: db,
		BooksDir:    booksDir,
		AuthToken:   authToken,
	}, nil
}
