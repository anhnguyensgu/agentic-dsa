package main

import (
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
)

// Progress is shared by every track, so there is one file to back up or
// commit instead of one per course.
type Progress struct {
	Last string              `json:"last"` // track used most recently
	Done map[string][]string `json:"done"` // track id -> finished exercise names

	path string
}

func loadProgress(path string) (*Progress, error) {
	p := &Progress{Done: map[string][]string{}, path: path}
	data, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return p, nil
	}
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(data, p); err != nil {
		return nil, err
	}
	if p.Done == nil {
		p.Done = map[string][]string{}
	}
	return p, nil
}

func (p *Progress) save() error {
	data, err := json.MarshalIndent(p, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(p.path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(p.path, append(data, '\n'), 0o644)
}

func (p *Progress) isDone(track, name string) bool {
	return slices.Contains(p.Done[track], name)
}

func (p *Progress) setDone(track, name string, done bool) {
	names := slices.DeleteFunc(p.Done[track], func(n string) bool { return n == name })
	if done {
		names = append(names, name)
	}
	p.Done[track] = names
}

func (p *Progress) count(t *Track) int {
	n := 0
	for _, ex := range t.Exercises {
		if p.isDone(t.id, ex.Name) {
			n++
		}
	}
	return n
}
