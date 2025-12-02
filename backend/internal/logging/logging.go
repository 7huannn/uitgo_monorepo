package logging

import (
	"encoding/json"
	"io"
	"log"
	"os"
	"strings"
	"sync"
	"time"
)

// Configure routes stdlib logging through a structured writer when requested.
func Configure(format, service string) {
	log.SetFlags(0)
	log.SetPrefix("")
	log.SetOutput(os.Stdout)

	if strings.EqualFold(strings.TrimSpace(format), "json") {
		log.SetOutput(&jsonWriter{
			out:     os.Stdout,
			service: service,
		})
	}
}

type jsonWriter struct {
	mu      sync.Mutex
	out     io.Writer
	service string
}

func (w *jsonWriter) Write(p []byte) (int, error) {
	w.mu.Lock()
	defer w.mu.Unlock()

	message := strings.TrimSpace(string(p))
	if message == "" {
		return len(p), nil
	}

	entry := map[string]any{
		"timestamp": time.Now().UTC().Format(time.RFC3339Nano),
		"message":   message,
	}
	if w.service != "" {
		entry["service"] = w.service
	}

	payload, err := json.Marshal(entry)
	if err != nil {
		return w.out.Write(p)
	}
	payload = append(payload, '\n')
	_, err = w.out.Write(payload)
	if err != nil {
		return 0, err
	}
	return len(p), nil
}
