package store

import (
	"context"
)

func (s *Store) InsertBook(ctx context.Context, title, author, filePath string) (*Book, error) {
	b := &Book{}
	err := s.db.QueryRow(ctx,
		`INSERT INTO books (title, author, file_path)
		 VALUES ($1, $2, $3)
		 RETURNING id, title, author, file_path, created_at`,
		title, author, filePath,
	).Scan(&b.ID, &b.Title, &b.Author, &b.FilePath, &b.CreatedAt)
	return b, err
}

func (s *Store) GetBook(ctx context.Context, id string) (*Book, error) {
	b := &Book{}
	err := s.db.QueryRow(ctx,
		`SELECT id, title, author, file_path, created_at FROM books WHERE id = $1`,
		id,
	).Scan(&b.ID, &b.Title, &b.Author, &b.FilePath, &b.CreatedAt)
	return b, err
}

func (s *Store) ListBooks(ctx context.Context) ([]Book, error) {
	rows, err := s.db.Query(ctx,
		`SELECT id, title, author, created_at FROM books ORDER BY created_at DESC`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var books []Book
	for rows.Next() {
		var b Book
		if err := rows.Scan(&b.ID, &b.Title, &b.Author, &b.CreatedAt); err != nil {
			return nil, err
		}
		books = append(books, b)
	}
	return books, rows.Err()
}
