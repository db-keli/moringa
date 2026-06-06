package store

import (
	"context"
	"encoding/json"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Store struct {
	db *pgxpool.Pool
}

func New(db *pgxpool.Pool) *Store {
	return &Store{db: db}
}

func Connect(ctx context.Context, dsn string) (*pgxpool.Pool, error) {
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		return nil, err
	}
	if err := pool.Ping(ctx); err != nil {
		return nil, err
	}
	return pool, nil
}

type Book struct {
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	Author    string    `json:"author"`
	Format    string    `json:"format"`
	FilePath  string    `json:"-"`
	CreatedAt time.Time `json:"created_at"`
}

type Event struct {
	ID        int64           `json:"id"`
	Device    string          `json:"device"`
	Seq       int64           `json:"seq"`
	Type      string          `json:"type"`
	Payload   json.RawMessage `json:"payload" swaggertype:"object"`
	CreatedAt time.Time       `json:"created_at"`
}

type Highlight struct {
	ID        string    `json:"id"`
	BookID    string    `json:"book_id"`
	StartPos  int64     `json:"start"`
	EndPos    int64     `json:"end"`
	Text      string    `json:"text"`
	Note      string    `json:"note"`
	Device    string    `json:"device"`
	CreatedAt time.Time `json:"created_at"`
}

type ReadingPosition struct {
	BookID     string    `json:"book_id"`
	Device     string    `json:"device"`
	ChunkIndex int       `json:"chunk_index"`
	Offset     int64     `json:"offset"`
	UpdatedAt  time.Time `json:"updated_at"`
}
