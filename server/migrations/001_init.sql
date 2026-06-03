CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS books (
    id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    title       TEXT NOT NULL,
    author      TEXT NOT NULL DEFAULT '',
    file_path   TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS events (
    id          BIGSERIAL PRIMARY KEY,
    device      TEXT NOT NULL,
    seq         BIGINT NOT NULL,
    type        TEXT NOT NULL,
    payload     JSONB NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (device, seq)
);

CREATE INDEX IF NOT EXISTS events_device_seq ON events (device, seq);
CREATE INDEX IF NOT EXISTS events_created_at ON events (created_at);

CREATE TABLE IF NOT EXISTS highlights (
    id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    book_id     TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    start_pos   BIGINT NOT NULL,
    end_pos     BIGINT NOT NULL,
    text        TEXT NOT NULL,
    note        TEXT NOT NULL DEFAULT '',
    device      TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS highlights_book_id ON highlights (book_id);

CREATE TABLE IF NOT EXISTS reading_positions (
    book_id     TEXT PRIMARY KEY REFERENCES books(id) ON DELETE CASCADE,
    device      TEXT NOT NULL,
    chunk_index INT NOT NULL DEFAULT 0,
    offset      BIGINT NOT NULL DEFAULT 0,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
