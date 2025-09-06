package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type requestPayload struct {
	Tokens []string          `json:"tokens"`
	Title  string            `json:"title"`
	Body   string            `json:"body"`
	Data   map[string]string `json:"data"`
}

type server struct {
	mc     *messaging.Client
	secret string
}

func newServer(credPath, secret string) (*server, error) {
	ctx := context.Background()
	if credPath == "" {
		credPath = os.Getenv("FIREBASE_CREDENTIALS")
	}
	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(credPath))
	if err != nil {
		return nil, err
	}
	mc, err := app.Messaging(ctx)
	if err != nil {
		return nil, err
	}
	return &server{mc: mc, secret: secret}, nil
}

func (s *server) handleSend(w http.ResponseWriter, r *http.Request) {
	if s.secret != "" {
		if r.Header.Get("X-Push-Secret") != s.secret {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
	}
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req requestPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	if len(req.Tokens) == 0 {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"sent":0}`))
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	// sanitize tokens: trim spaces/newlines
	sent := 0
	for i, t := range req.Tokens {
		t = strings.TrimSpace(t)
		if t == "" {
			log.Printf("skip empty token at index %d", i)
			continue
		}
		if len(t) < 50 { // coarse check to catch obvious copy mistakes
			log.Printf("token too short (%d chars), idx=%d, prefix=%q", len(t), i, t)
		} else {
			log.Printf("sending to token[%d] len=%d prefix=%q", i, len(t), t[:12])
		}
		_, err := s.mc.Send(ctx, &messaging.Message{
			Token:        t,
			Notification: &messaging.Notification{Title: req.Title, Body: req.Body},
			Data:         req.Data,
		})
		if err != nil {
			log.Printf("send token failed (idx=%d): %v", i, err)
			continue
		}
		sent++
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]int{"sent": sent})
}

func main() {
	addr := ":8090"
	cred := os.Getenv("FIREBASE_CREDENTIALS")
	if cred == "" {
		log.Fatal("FIREBASE_CREDENTIALS wajib diisi untuk push-service")
	}
	s, err := newServer(cred, os.Getenv("PUSH_SERVICE_SECRET"))
	if err != nil {
		log.Fatal(err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/send", s.handleSend)

	log.Printf("push-service listen %s\n", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}
