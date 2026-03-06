package main

import (
	_ "embed"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
)

var (
	appDirectory = env("APP_DIRECTORY")
	activeApp    *exec.Cmd
	mu           sync.Mutex

	//go:embed templates/index.tmpl
	homeHtml string
	homeTmpl = template.Must(template.New("index").Parse(homeHtml))
)

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /", homePage)
	mux.HandleFunc("POST /start", startApp)
	mux.HandleFunc("POST /stop", stopApp)

	host, port := env("HOST"), env("PORT")
	addr := fmt.Sprintf("%v:%v", host, port)

	log.Println("listening on", addr)

	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Panic("failed to start server:", err)
	}
}

/* Routes */

func homePage(w http.ResponseWriter, r *http.Request) {
	var apps []string

	err := filepath.WalkDir(appDirectory, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}

		if d.IsDir() {
			return nil
		}

		info, err := d.Info()
		if err != nil {
			return err
		}

		if info.Mode()&0o111 != 0 {
			apps = append(apps, d.Name())
		}

		return nil
	})
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	homeTmpl.Execute(w, struct {
		Apps []string
	}{Apps: apps})
}

func startApp(w http.ResponseWriter, r *http.Request) {
	appName := r.URL.Query().Get("app")
	if appName == "" {
		http.Error(w, "missing app parameter", http.StatusBadRequest)
		return
	}

	target := filepath.Join(appDirectory, appName)

	if _, err := os.Stat(target); err != nil {
		http.Error(w, "executable not found", http.StatusNotFound)
		return
	}

	// Kill any existing active application, since there can only be one
	if err := killActiveApp(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Start the application
	cmd := exec.Command(target)
	if err := cmd.Start(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	mu.Lock()
	activeApp = cmd
	mu.Unlock()

	w.WriteHeader(http.StatusOK)
}

func stopApp(w http.ResponseWriter, r *http.Request) {
	if err := killActiveApp(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

/* Utilities */

func killActiveApp() error {
	mu.Lock()
	defer mu.Unlock()

	if activeApp == nil {
		return nil
	}

	if activeApp.Process != nil {
		if err := activeApp.Process.Kill(); err != nil {
			return err
		}
	}

	activeApp = nil
	return nil
}

func env(key string) string {
	value, found := os.LookupEnv(key)
	if !found {
		log.Panic("environment variable not set:", key)
	}

	return value
}
