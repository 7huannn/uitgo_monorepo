package handlers

import (
	"context"
	"errors"
	"log"
	"math"
	"net/http"

	"github.com/gin-gonic/gin"

	"uitgo/backend/internal/routing"
)

type routeRequest struct {
	Origin      *latLng `json:"origin" binding:"required"`
	Destination *latLng `json:"destination" binding:"required"`
}

type latLng struct {
	Lat float64 `json:"lat" binding:"required"`
	Lng float64 `json:"lng" binding:"required"`
}

type routeResponse struct {
	Distance    float64        `json:"distance"`
	Duration    float64        `json:"duration"`
	Coordinates [][]float64    `json:"coordinates"`
	Steps       []routeStep    `json:"steps"`
}

type routeStep struct {
	Name        string    `json:"name"`
	Instruction string    `json:"instruction"`
	Location    []float64 `json:"location"`
	Distance    float64   `json:"distance"`
	Duration    float64   `json:"duration"`
}

// RegisterRouteRoutes registers /routes endpoint on the provided router.
func RegisterRouteRoutes(router gin.IRouter, provider RoutingProvider) {
	if router == nil || provider == nil {
		return
	}
	handler := &routeHandler{provider: provider}
	router.POST("/routes", handler.getRoute)
}

type routeHandler struct {
	provider RoutingProvider
}

func (h *routeHandler) getRoute(c *gin.Context) {
	var req routeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if req.Origin == nil || req.Destination == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "origin and destination are required"})
		return
	}
	if !validLatLng(req.Origin.Lat, req.Origin.Lng) || !validLatLng(req.Destination.Lat, req.Destination.Lng) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "lat/lng must be valid coordinates"})
		return
	}

	route, err := h.provider.GetRoute(
		c.Request.Context(),
		routing.Coordinate{Lat: req.Origin.Lat, Lng: req.Origin.Lng},
		routing.Coordinate{Lat: req.Destination.Lat, Lng: req.Destination.Lng},
	)
	if err != nil {
		status := http.StatusBadGateway
		message := "routing service unavailable"
		if errors.Is(err, routing.ErrRouteNotFound) {
			status = http.StatusNotFound
			message = "no route found"
		}
		log.Printf("routing lookup failed: %v", err)
		c.JSON(status, gin.H{"error": message})
		return
	}

	c.JSON(http.StatusOK, routeResponse{
		Distance:    route.Distance,
		Duration:    route.Duration,
		Coordinates: normalizeCoordinates(route.Coordinates),
		Steps:       mapSteps(route.Steps),
	})
}

func validLatLng(lat, lng float64) bool {
	return !math.IsNaN(lat) && !math.IsNaN(lng) &&
		lat <= 90 && lat >= -90 &&
		lng <= 180 && lng >= -180
}

func mapSteps(steps []routing.Step) []routeStep {
	if len(steps) == 0 {
		return nil
	}
	mapped := make([]routeStep, 0, len(steps))
	for _, step := range steps {
		mapped = append(mapped, routeStep{
			Name:        step.Name,
			Instruction: step.Instruction,
			Location:    normalizeLocation(step.Location),
			Distance:    step.Distance,
			Duration:    step.Duration,
		})
	}
	return mapped
}

func normalizeCoordinates(coords [][]float64) [][]float64 {
	if len(coords) == 0 {
		return nil
	}
	normalized := make([][]float64, 0, len(coords))
	for _, pair := range coords {
		if len(pair) >= 2 {
			normalized = append(normalized, []float64{pair[0], pair[1]})
		}
	}
	return normalized
}

func normalizeLocation(loc []float64) []float64 {
	if len(loc) < 2 {
		return nil
	}
	return []float64{loc[0], loc[1]}
}

// RoutingProvider describes the behaviour needed by the routing handler.
type RoutingProvider interface {
	GetRoute(ctx context.Context, origin, destination routing.Coordinate) (*routing.Route, error)
}
