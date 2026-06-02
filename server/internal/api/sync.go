package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"

	"github.com/kekelidompeh/moringa/internal/store"
)

type ingestRequest struct {
	Device  string          `json:"device"`
	Seq     int64           `json:"seq"`
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload"`
}

func (h *Handler) ingestEvent(w http.ResponseWriter, r *http.Request) {
	var req ingestRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if req.Device == "" || req.Type == "" {
		writeError(w, http.StatusBadRequest, "device and type are required")
		return
	}
	if req.Payload == nil {
		req.Payload = json.RawMessage("{}")
	}

	event, err := h.store.InsertEvent(r.Context(), req.Device, req.Seq, req.Type, req.Payload)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to store event")
		return
	}

	h.broker.Publish(*event)
	writeJSON(w, http.StatusCreated, event)
}

func (h *Handler) stream(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		writeError(w, http.StatusInternalServerError, "streaming not supported")
		return
	}

	clock := parseVectorClock(r)

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(http.StatusOK)

	missed, err := h.store.EventsSince(r.Context(), clock)
	if err == nil {
		for _, e := range missed {
			writeSSEEvent(w, e)
		}
		flusher.Flush()
	}

	ch := h.broker.Subscribe()
	defer h.broker.Unsubscribe(ch)

	for {
		select {
		case e, ok := <-ch:
			if !ok {
				return
			}
			writeSSEEvent(w, e)
			flusher.Flush()
		case <-r.Context().Done():
			return
		}
	}
}

func writeSSEEvent(w http.ResponseWriter, e store.Event) {
	b, _ := json.Marshal(e)
	fmt.Fprintf(w, "data: %s\n\n", b) //nolint:errcheck
}

func parseVectorClock(r *http.Request) store.VectorClock {
	clock := store.VectorClock{}
	for device, vals := range r.URL.Query() {
		if len(vals) > 0 {
			if seq, err := strconv.ParseInt(vals[0], 10, 64); err == nil {
				clock[device] = seq
			}
		}
	}
	return clock
}
