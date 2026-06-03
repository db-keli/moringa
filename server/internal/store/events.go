package store

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/jackc/pgx/v5"
)

type VectorClock map[string]int64

func (s *Store) InsertEvent(
	ctx context.Context,
	device string,
	seq int64,
	eventType string,
	payload json.RawMessage,
) (*Event, error) {
	e := &Event{}
	err := s.db.QueryRow(
		ctx,
		`INSERT INTO events (device, seq, type, payload)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (device, seq) DO NOTHING
		 RETURNING id, device, seq, type, payload, created_at`,
		device, seq, eventType, payload,
	).Scan(&e.ID, &e.Device, &e.Seq, &e.Type, &e.Payload, &e.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		err = s.db.QueryRow(
			ctx,
			`SELECT id, device, seq, type, payload, created_at
			 FROM events WHERE device = $1 AND seq = $2`,
			device, seq,
		).Scan(&e.ID, &e.Device, &e.Seq, &e.Type, &e.Payload, &e.CreatedAt)
	}
	return e, err
}

func (s *Store) EventsSince(ctx context.Context, clock VectorClock) ([]Event, error) {
	// Build a query that returns events beyond what the client has seen.
	// For devices not in the clock, seq > -1 returns all events from that device.
	rows, err := s.db.Query(
		ctx,
		`SELECT id, device, seq, type, payload, created_at
		 FROM events
		 WHERE seq > COALESCE(
		   (SELECT value::bigint
		    FROM jsonb_each_text($1::jsonb)
		    WHERE key = device
		    LIMIT 1), -1
		 )
		 ORDER BY created_at ASC`,
		clockToJSON(clock),
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var events []Event
	for rows.Next() {
		var e Event
		if err := rows.Scan(
			&e.ID,
			&e.Device,
			&e.Seq,
			&e.Type,
			&e.Payload,
			&e.CreatedAt,
		); err != nil {
			return nil, err
		}
		events = append(events, e)
	}
	return events, rows.Err()
}

func clockToJSON(clock VectorClock) []byte {
	b, _ := json.Marshal(clock)
	return b
}
