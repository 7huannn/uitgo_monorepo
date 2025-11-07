package handlers

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"uitgo/backend/internal/domain"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 1024
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

type inboundMessage struct {
	Type   string  `json:"type"`
	Status string  `json:"status,omitempty"`
	Lat    float64 `json:"lat,omitempty"`
	Lng    float64 `json:"lng,omitempty"`
}

type outboundMessage struct {
	Type      string                 `json:"type"`
	TripID    string                 `json:"tripId"`
	Status    domain.TripStatus      `json:"status,omitempty"`
	Location  *domain.LocationUpdate `json:"location,omitempty"`
	Timestamp time.Time              `json:"timestamp"`
}

type Client struct {
	hub    *Hub
	conn   *websocket.Conn
	send   chan []byte
	role   string
	userID string
	tripID string
	ctx    context.Context
}

func (c *Client) readPump(service *domain.TripService) {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()
	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})
	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("ws unexpected close: %v", err)
			}
			break
		}
		if c.role != "driver" {
			continue
		}
		var inbound inboundMessage
		if err := json.Unmarshal(message, &inbound); err != nil {
			log.Printf("ws parse message: %v", err)
			continue
		}

		switch inbound.Type {
		case "location":
			update := domain.LocationUpdate{
				Latitude:  inbound.Lat,
				Longitude: inbound.Lng,
				Timestamp: time.Now().UTC(),
			}
			if err := service.RecordLocation(c.ctx, c.tripID, update); err != nil {
				log.Printf("save location: %v", err)
				continue
			}
			c.hub.broadcastJSON(outboundMessage{
				Type:      "location",
				TripID:    c.tripID,
				Location:  &update,
				Timestamp: update.Timestamp,
			})
		case "status":
			if inbound.Status == "" {
				continue
			}
			status := domain.TripStatus(inbound.Status)
			if err := service.UpdateStatus(c.ctx, c.tripID, status); err != nil {
				log.Printf("update status: %v", err)
				continue
			}
			c.hub.broadcastJSON(outboundMessage{
				Type:      "status",
				TripID:    c.tripID,
				Status:    status,
				Timestamp: time.Now().UTC(),
			})
		}
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()
	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

type Hub struct {
	tripID     string
	service    *domain.TripService
	clients    map[*Client]struct{}
	register   chan *Client
	unregister chan *Client
	broadcast  chan []byte
}

func newHub(tripID string, service *domain.TripService) *Hub {
	return &Hub{
		tripID:     tripID,
		service:    service,
		clients:    make(map[*Client]struct{}),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan []byte, 16),
	}
}

func (h *Hub) run() {
	for {
		select {
		case client := <-h.register:
			h.clients[client] = struct{}{}
		case client := <-h.unregister:
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			}
		case message := <-h.broadcast:
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client)
				}
			}
		}
	}
}

func (h *Hub) broadcastJSON(msg outboundMessage) {
	payload, err := json.Marshal(msg)
	if err != nil {
		log.Printf("marshal ws message: %v", err)
		return
	}
	h.broadcast <- payload
}

type HubManager struct {
	service *domain.TripService
	hubs    map[string]*Hub
	mu      sync.RWMutex
}

// NewHubManager constructs a HubManager.
func NewHubManager(service *domain.TripService) *HubManager {
	return &HubManager{
		service: service,
		hubs:    make(map[string]*Hub),
	}
}

func (m *HubManager) get(tripID string) *Hub {
	m.mu.RLock()
	hub, exists := m.hubs[tripID]
	m.mu.RUnlock()
	if exists {
		return hub
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	if hub, exists = m.hubs[tripID]; exists {
		return hub
	}
	hub = newHub(tripID, m.service)
	m.hubs[tripID] = hub
	go hub.run()
	return hub
}

// BroadcastStatus notifies subscribers about a status change.
func (m *HubManager) BroadcastStatus(tripID string, status domain.TripStatus) {
	hub := m.get(tripID)
	hub.broadcastJSON(outboundMessage{
		Type:      "status",
		TripID:    tripID,
		Status:    status,
		Timestamp: time.Now().UTC(),
	})
}

// HandleWebsocket upgrades the connection and starts client pumps.
func (m *HubManager) HandleWebsocket(service *domain.TripService) gin.HandlerFunc {
	return func(c *gin.Context) {
		tripID := c.Param("id")
		conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			log.Printf("upgrade websocket: %v", err)
			return
		}
		roleVal, _ := c.Get("role")
		roleStr, _ := roleVal.(string)
		userVal, _ := c.Get("userID")
		userStr, _ := userVal.(string)
		if roleStr == "" {
			if queryRole := c.Query("role"); queryRole != "" {
				roleStr = queryRole
			}
		}
		if queryUser := c.Query("userId"); queryUser != "" {
			userStr = queryUser
		}
		if userStr == "" {
			userStr = "demo-user"
		}

		hub := m.get(tripID)
		client := &Client{
			hub:    hub,
			conn:   conn,
			send:   make(chan []byte, 16),
			role:   roleStr,
			userID: userStr,
			tripID: tripID,
			ctx:    c.Request.Context(),
		}
		hub.register <- client

		go client.writePump()

		// Send snapshot data for riders.
		if roleStr != "driver" {
			if trip, err := service.Fetch(c.Request.Context(), tripID); err == nil && trip != nil {
				if payload, err := json.Marshal(outboundMessage{
					Type:      "status",
					TripID:    tripID,
					Status:    trip.Status,
					Timestamp: time.Now().UTC(),
				}); err == nil {
					client.send <- payload
				}
			}
			if location, err := service.LatestLocation(c.Request.Context(), tripID); err == nil && location != nil {
				if payload, err := json.Marshal(outboundMessage{
					Type:      "location",
					TripID:    tripID,
					Location:  location,
					Timestamp: location.Timestamp,
				}); err == nil {
					client.send <- payload
				}
			}
		}

		client.readPump(service)
	}
}
