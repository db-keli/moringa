# Moringa — Design Document

A self-hosted reading and writing workspace. Books, highlights, notes, and blog drafts — synced across Mac and phone, stored on your own server.

---

## What it is

One person. Two devices (Mac, phone). One server. Everything in sync.

You read a book on your Mac, add a highlight, pick up your phone — the highlight is there. You draft a blog post on your phone, open your Mac — the draft is there. You go offline on a plane — everything still works.

That is the whole product.

---

## Core Principle: Local-First

Every read and write goes to a local SQLite database on the device first. The server is a sync bus, not an authority.

**Why:** A reading and writing app must feel instant. Waiting 80ms for a server round-trip on every keystroke or page turn is the difference between a tool that feels native and one that feels like a web app. SQLite on disk is ~0ms. The server never touches the critical path.

**Consequence:** The app works fully offline. Sync drains when connectivity returns.

---

## Data Architecture

### On each device — SQLite

Every device holds a complete local copy of the user's data.

```
book_chunks       — chapter content, cached after first download
reading_state     — current position per book (chapter, offset)
highlights        — all highlights, all books
notes             — personal notes
blogs             — draft blog posts
fts5_index        — unified full-text search index (virtual table)
sync_queue        — outbound events not yet confirmed by server
vector_clock      — { mac: N, phone: M } — tracks sync position
```

### On the server — PostgreSQL + filesystem

```
events            — append-only event log (source of truth for sync)
books             — book metadata (title, author, cover)
highlights        — materialized from events (query convenience)
positions         — materialized from events (query convenience)

/books/{id}/chunks.json   — pre-parsed EPUB chapters (filesystem)
/books/{id}/original.epub — original upload (filesystem)
```

The event log is the authoritative record. The materialized tables are derived from it and can be rebuilt.

---

## Sync Protocol

### Transport: SSE for delivery, HTTP POST for writes

When the app opens or comes to foreground, it opens an SSE connection to the server, passing its current vector clock:

```
GET /stream?mac=44&phone=31
```

The server streams every event the device hasn't seen yet, then holds the connection open and pushes new events as they arrive.

Writes go via HTTP POST:

```
POST /events
{ device: "mac", seq: 45, type: "highlight_added", payload: {...} }
```

**Why SSE over WebSockets:** The sync communication is asymmetric — the server pushes to clients, clients post to the server. SSE models this exactly, with simpler reconnect handling and no extra protocol overhead. WebSockets are the right tool for bidirectional real-time (chat, collaboration). This is not that.

**Why not polling:** A 5–30 second polling interval produces a visible lag when switching devices mid-thought. SSE gives sub-second delivery with no meaningful battery cost compared to polling.

### Sync Data Model: Event Log with Vector Clocks

Each write produces an event:

```json
{
  "device": "mac",
  "seq": 45,
  "type": "highlight_added",
  "payload": {
    "book_id": "abc",
    "start": 400,
    "end": 500,
    "text": "the map is not the territory"
  },
  "ts": 1748700000
}
```

Devices track what they have seen with a vector clock `{ mac: 44, phone: 31 }`. On reconnect, they request all events beyond their last known sequence per device.

**Why event log over full document sync:** Full document sync (send the whole file) loses data when two devices edit offline simultaneously — last write wins, one device's edits disappear. An event log captures every fact independently. Merging on reconnect means applying the unseen events in order; since this is one person, conflicts are rare, and when they occur (e.g. position updated on both devices while offline) last-write-wins per field is acceptable.

**Why event log over CRDTs / Operational Transforms:** CRDTs give conflict-free merges for collaborative text editing. The engineering cost is high. For a single-user system, the conflict rate is low enough that a simpler model works. If real-time collaboration ever becomes a goal, the event log can be replaced without touching the rest of the architecture.

**Idempotency:** Applying an event that already exists is a no-op (checked by device+seq). This means the device can safely retry on network failure.

---

## Read Paths

### Opening a book (warm)

```
User opens book
→ SELECT position FROM reading_state WHERE book_id = ?
→ SELECT content FROM book_chunks WHERE book_id = ? AND chunk = ?
→ render at saved offset
Latency: ~0ms
```

### Opening a book (cold — first time on this device)

```
User opens book
→ SQLite miss
→ show loading indicator
→ GET /books/{id}/chunks
→ server reads chunks.json from filesystem, streams response
→ device INSERTs all chunks into SQLite
→ render chapter 1
Latency: 200–800ms (one-time cost, never repeated)
```

Books are immutable content. Once cached, a book never hits the server again for its content. Only highlights, position, and notes sync.

### Search

```
User types query
→ SELECT * FROM fts5_index WHERE fts5_index MATCH ?
  (covers book_chunks, highlights, notes, blogs in one query)
→ render results
Latency: ~5ms

If local returns 0 results:
→ GET /search?q={query}  (hits PostgreSQL full-text)
→ merge with local, deduplicate by event_id
→ render combined results
Latency: 80–200ms (fallback only)
```

FTS5 is the right tool for a single-user corpus. It handles millions of rows, supports ranking, prefix search, and phrase matching. The server fallback covers content that hasn't been synced to this device yet.

### Receiving a sync update

```
SSE event arrives
→ check vector_clock: have I seen device:seq already?
   yes → skip (idempotent)
   no  → apply event to local SQLite
       → update fts5_index
       → update vector_clock
       → re-render affected UI if visible
```

---

## Write Path: Optimistic Local-First

```
User types / highlights / saves
→ write to local SQLite immediately   (~0ms, UI updates)
→ enqueue event in sync_queue
→ POST /events to server (background)
   success → mark event synced, remove from queue
   failure → retry with exponential backoff
             queue survives app restart
```

The user never waits for the server. From the UI's perspective, every write is instant. The sync queue handles delivery guarantees.

---

## Book Import

EPUB import happens server-side.

```
User uploads EPUB
→ POST /books/import (multipart)
→ server parses EPUB: extract chapters, images, metadata
→ writes chunks.json to /books/{id}/
→ writes metadata to PostgreSQL
→ pushes book_imported event to all devices via SSE
→ devices fetch chunks on next book open (cold load path)
```

**Why server-side parsing:** EPUB parsing is CPU-heavy and produces a large output. Doing it on-device would drain battery and require the full parsing library on both Mac and phone. The server does it once; devices get the pre-parsed result.

---

## Technology Stack

| Layer | Choice | Reason |
|---|---|---|
| Backend | Go | Fast, small binaries, straightforward concurrency for SSE |
| Database | PostgreSQL | Reliable, good full-text search, familiar |
| Book storage | Filesystem | No overhead, easy backup, readable files |
| Mac app | Tauri (Rust) | Native performance, small binary, access to local SQLite |
| Phone app | React Native | Code sharing for sync logic, SQLite via op-sqlite |
| Client DB | SQLite + FTS5 | Zero-latency reads, built-in full-text search, offline |
| Sync transport | SSE | Simple, reconnect-safe, right fit for server-push pattern |
| Hosting | Single VPS | $6–20/month, one machine, straightforward ops |

---

## Server Infrastructure

Single machine. No microservices.

```
Ubuntu VPS
├── Caddy          (TLS, reverse proxy)
├── Go API         (sync, book serving, import)
├── PostgreSQL     (event log, metadata)
└── /var/moringa/  (book chunks, uploads)
```

Docker Compose ties it together. `pg_dump` to object storage nightly for backup.

This is sufficient for one person's reading and writing data for years. The architecture scales up naturally — object storage replaces the filesystem, read replicas handle query load — but there is no reason to build that complexity now.

---

## What is explicitly out of scope

- **Multi-user / sharing** — this is a personal tool. No access control beyond a single auth token.
- **Real-time collaboration** — one person edits at a time. No OT or CRDT.
- **PDF annotation** — reading and highlighting only for EPUB and Markdown. PDFs are import-only (read as text, no annotation layer).
- **Cloud hosting option** — self-hosted only. That is the point.
- **Mobile book import** — upload happens from Mac or web. Phone is read/write for notes and highlights, not for importing new books.

---

## Open Questions (validate before building)

1. **SQLite FTS5 on iOS** — `op-sqlite` exposes FTS5 on Android; iOS support needs verification before committing to this as the search path.
2. **EPUB rendering quality** — existing Rust/JS EPUB renderers vary widely. Prototype the renderer against a few complex EPUBs (tables, images, footnotes) before committing to a library.
3. **Chunk granularity** — chapter-level chunks are the default assumption. Very long chapters (>100KB) may need sub-chapter splitting for acceptable cold-load performance on mobile.
