// Package order is an in-memory order book for the reference service.
// Persistence is intentionally out of the golden path.
package order

import (
	"crypto/rand"
	"encoding/hex"
	"sync"
	"time"
)

// Order is the API representation returned to callers.
type Order struct {
	ID        string    `json:"id"`
	SKU       string    `json:"sku"`
	Qty       int       `json:"qty"`
	CreatedAt time.Time `json:"created_at"`
}

// Store keeps orders for the life of the process.
type Store struct {
	mu     sync.RWMutex
	orders map[string]Order
}

// NewStore returns an empty store.
func NewStore() *Store {
	return &Store{orders: make(map[string]Order)}
}

// Create records an order and returns it.
func (s *Store) Create(sku string, qty int) Order {
	s.mu.Lock()
	defer s.mu.Unlock()

	o := Order{
		ID:        newID(),
		SKU:       sku,
		Qty:       qty,
		CreatedAt: time.Now().UTC(),
	}
	s.orders[o.ID] = o
	return o
}

// Get returns an order by id.
func (s *Store) Get(id string) (Order, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	o, ok := s.orders[id]
	return o, ok
}

func newID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		// crypto/rand failure means the process cannot continue safely.
		panic(err)
	}
	return hex.EncodeToString(b[:])
}
