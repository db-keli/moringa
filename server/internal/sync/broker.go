package sync

import (
	"sync"

	"github.com/kekelidompeh/moringa/internal/store"
)

type Broker struct {
	mu      sync.RWMutex
	clients map[chan store.Event]struct{}
}

func NewBroker() *Broker {
	return &Broker{
		clients: make(map[chan store.Event]struct{}),
	}
}

func (b *Broker) Subscribe() chan store.Event {
	ch := make(chan store.Event, 16)
	b.mu.Lock()
	b.clients[ch] = struct{}{}
	b.mu.Unlock()
	return ch
}

func (b *Broker) Unsubscribe(ch chan store.Event) {
	b.mu.Lock()
	delete(b.clients, ch)
	close(ch)
	b.mu.Unlock()
}

func (b *Broker) Publish(e store.Event) {
	b.mu.RLock()
	defer b.mu.RUnlock()
	for ch := range b.clients {
		select {
		case ch <- e:
		default:
		}
	}
}
