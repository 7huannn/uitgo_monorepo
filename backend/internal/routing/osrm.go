package routing

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

const (
	defaultBaseURL         = "https://router.project-osrm.org"
	defaultRequestTimeout  = 8 * time.Second
	fallbackAverageSpeedMS = 11.0 // ~40km/h
)

// ErrRouteNotFound indicates the routing engine could not find a path.
var ErrRouteNotFound = errors.New("no route found")

// Coordinate represents a lat/lng pair.
type Coordinate struct {
	Lat float64
	Lng float64
}

// Step represents a single maneuver in the route.
type Step struct {
	Name        string
	Instruction string
	Location    []float64
	Distance    float64
	Duration    float64
}

// Route is the normalized routing response returned to callers.
type Route struct {
	Distance    float64
	Duration    float64
	Coordinates [][]float64
	Steps       []Step
}

// Client calls an OSRM-compatible routing API.
type Client struct {
	baseURL    string
	httpClient *http.Client
	cacheTTL   time.Duration

	mu    sync.RWMutex
	cache map[string]cachedRoute
}

type cachedRoute struct {
	route     *Route
	expiresAt time.Time
}

// NewClient creates a routing client with optional caching.
func NewClient(baseURL string, timeout, cacheTTL time.Duration) *Client {
	baseURL = strings.TrimSpace(baseURL)
	if baseURL == "" {
		baseURL = defaultBaseURL
	}
	baseURL = strings.TrimSuffix(baseURL, "/")
	if timeout <= 0 {
		timeout = defaultRequestTimeout
	}
	if cacheTTL < 0 {
		cacheTTL = 0
	}

	return &Client{
		baseURL:    baseURL,
		httpClient: &http.Client{Timeout: timeout},
		cacheTTL:   cacheTTL,
		cache:      make(map[string]cachedRoute),
	}
}

// GetRoute fetches a driving route between origin and destination.
func (c *Client) GetRoute(ctx context.Context, origin, destination Coordinate) (*Route, error) {
	key := cacheKey(origin, destination)
	if cached := c.fromCache(key); cached != nil {
		return cached, nil
	}

	requestURL, err := c.buildURL(origin, destination)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return c.syntheticRoute(origin, destination, fmt.Errorf("routing request: %w", err))
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return nil, ErrRouteNotFound
	}
	if resp.StatusCode != http.StatusOK {
		return c.syntheticRoute(origin, destination, fmt.Errorf("routing upstream returned %d", resp.StatusCode))
	}

	var payload osrmResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return c.syntheticRoute(origin, destination, fmt.Errorf("decode routing response: %w", err))
	}

	route, err := mapOSRM(&payload)
	if err != nil {
		return nil, err
	}

	c.saveCache(key, route)
	return route, nil
}

func (c *Client) buildURL(origin, destination Coordinate) (string, error) {
	raw := fmt.Sprintf("%s/route/v1/driving/%f,%f;%f,%f", c.baseURL, origin.Lng, origin.Lat, destination.Lng, destination.Lat)
	parsed, err := url.Parse(raw)
	if err != nil {
		return "", err
	}
	query := parsed.Query()
	query.Set("overview", "full")
	query.Set("geometries", "geojson")
	query.Set("steps", "true")
	parsed.RawQuery = query.Encode()
	return parsed.String(), nil
}

func (c *Client) fromCache(key string) *Route {
	if c.cacheTTL == 0 {
		return nil
	}
	now := time.Now()
	c.mu.RLock()
	entry, ok := c.cache[key]
	c.mu.RUnlock()
	if !ok || now.After(entry.expiresAt) {
		return nil
	}
	return entry.route
}

func (c *Client) saveCache(key string, route *Route) {
	if c.cacheTTL == 0 || route == nil {
		return
	}
	expiry := time.Now().Add(c.cacheTTL)
	c.mu.Lock()
	c.cache[key] = cachedRoute{route: route, expiresAt: expiry}
	c.mu.Unlock()
}

func cacheKey(origin, destination Coordinate) string {
	return fmt.Sprintf("%.5f,%.5f|%.5f,%.5f", origin.Lat, origin.Lng, destination.Lat, destination.Lng)
}

type osrmResponse struct {
	Code    string      `json:"code"`
	Message string      `json:"message"`
	Routes  []osrmRoute `json:"routes"`
}

type osrmRoute struct {
	Distance float64      `json:"distance"`
	Duration float64      `json:"duration"`
	Geometry osrmGeometry `json:"geometry"`
	Legs     []osrmLeg    `json:"legs"`
}

type osrmGeometry struct {
	Coordinates [][]float64 `json:"coordinates"`
}

type osrmLeg struct {
	Steps []osrmStep `json:"steps"`
}

type osrmStep struct {
	Name     string       `json:"name"`
	Distance float64      `json:"distance"`
	Duration float64      `json:"duration"`
	Maneuver osrmManeuver `json:"maneuver"`
}

type osrmManeuver struct {
	Instruction string    `json:"instruction"`
	Type        string    `json:"type"`
	Modifier    string    `json:"modifier"`
	Location    []float64 `json:"location"`
}

func mapOSRM(resp *osrmResponse) (*Route, error) {
	if resp == nil {
		return nil, ErrRouteNotFound
	}
	if resp.Code != "" && !strings.EqualFold(resp.Code, "ok") {
		if resp.Message != "" {
			return nil, fmt.Errorf("%w: %s", ErrRouteNotFound, strings.TrimSpace(resp.Message))
		}
		return nil, fmt.Errorf("%w: %s", ErrRouteNotFound, resp.Code)
	}
	if len(resp.Routes) == 0 {
		return nil, ErrRouteNotFound
	}
	first := resp.Routes[0]
	steps := flattenSteps(first.Legs)
	return &Route{
		Distance:    first.Distance,
		Duration:    first.Duration,
		Coordinates: first.Geometry.Coordinates,
		Steps:       steps,
	}, nil
}

func flattenSteps(legs []osrmLeg) []Step {
	if len(legs) == 0 {
		return nil
	}
	var steps []Step
	for _, leg := range legs {
		for _, step := range leg.Steps {
			instruction := buildInstruction(step.Maneuver.Instruction, step.Maneuver.Type, step.Maneuver.Modifier, step.Name)
			steps = append(steps, Step{
				Name:        strings.TrimSpace(step.Name),
				Instruction: instruction,
				Location:    normalizeLocation(step.Maneuver.Location),
				Distance:    step.Distance,
				Duration:    step.Duration,
			})
		}
	}
	return steps
}

func normalizeLocation(location []float64) []float64 {
	if len(location) < 2 {
		return nil
	}
	return []float64{location[0], location[1]}
}

func buildInstruction(raw, typ, modifier, street string) string {
	raw = strings.TrimSpace(raw)
	if raw != "" {
		return raw
	}
	typ = prettify(typ)
	modifier = prettify(modifier)
	street = strings.TrimSpace(street)

	switch {
	case typ != "" && modifier != "" && street != "":
		return fmt.Sprintf("%s %s toward %s", typ, modifier, street)
	case typ != "" && modifier != "":
		return fmt.Sprintf("%s %s", typ, modifier)
	case typ != "" && street != "":
		return fmt.Sprintf("%s toward %s", typ, street)
	case street != "":
		return fmt.Sprintf("Continue toward %s", street)
	case typ != "":
		return typ
	default:
		return "Continue"
	}
}

func prettify(text string) string {
	text = strings.ReplaceAll(strings.TrimSpace(text), "_", " ")
	if text == "" {
		return ""
	}
	lower := strings.ToLower(text)
	return strings.ToUpper(lower[:1]) + lower[1:]
}

func (c *Client) syntheticRoute(origin, destination Coordinate, reason error) (*Route, error) {
	if reason != nil {
		log.Printf("routing upstream unavailable, using fallback: %v", reason)
	}
	distance := haversineDistance(origin, destination)
	if distance <= 0 {
		return nil, fmt.Errorf("unable to compute fallback route")
	}
	duration := distance / fallbackAverageSpeedMS
	if duration < 60 {
		duration = 60
	}

	coords := [][]float64{
		{origin.Lng, origin.Lat},
		{destination.Lng, destination.Lat},
	}
	step := Step{
		Name:        "Direct route",
		Instruction: "Proceed to your destination",
		Location:    []float64{origin.Lng, origin.Lat},
		Distance:    distance,
		Duration:    duration,
	}

	route := &Route{
		Distance:    distance,
		Duration:    duration,
		Coordinates: coords,
		Steps:       []Step{step},
	}
	c.saveCache(cacheKey(origin, destination), route)
	return route, nil
}

func haversineDistance(a, b Coordinate) float64 {
	const earthRadius = 6371000.0
	lat1 := toRadians(a.Lat)
	lat2 := toRadians(b.Lat)
	deltaLat := toRadians(b.Lat - a.Lat)
	deltaLng := toRadians(b.Lng - a.Lng)

	sinLat := math.Sin(deltaLat / 2)
	sinLng := math.Sin(deltaLng / 2)

	h := sinLat*sinLat + math.Cos(lat1)*math.Cos(lat2)*sinLng*sinLng
	c := 2 * math.Atan2(math.Sqrt(h), math.Sqrt(1-h))
	return earthRadius * c
}

func toRadians(deg float64) float64 {
	return deg * math.Pi / 180
}
