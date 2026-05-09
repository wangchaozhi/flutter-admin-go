package main

import (
	"flag"
	"log"
	"net/http"

	"flutter-admin-go/internal/config"
	"flutter-admin-go/internal/server"
	"flutter-admin-go/internal/store"
)

func main() {
	cfgPath := flag.String("config", "config/local.yml", "path to config file")
	flag.Parse()

	cfg, err := config.Load(*cfgPath)
	if err != nil {
		log.Fatal(err)
	}

	if err := store.Init(cfg); err != nil {
		log.Fatal(err)
	}

	handler := server.NewRouter()
	log.Printf("server started at http://localhost%s", cfg.Server.Addr)
	if err := http.ListenAndServe(cfg.Server.Addr, handler); err != nil {
		log.Fatal(err)
	}
}
