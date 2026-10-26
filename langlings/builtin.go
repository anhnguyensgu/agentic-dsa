package main

import (
	"embed"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

// Built-in courses ship inside langlings: every folder in builtin/ with a
// track.toml is one. Only what a learner needs is embedded; solutions/ and
// dev/ stay in the source.
//
//go:embed builtin/*/track.toml builtin/*/README.md builtin/*/exercises
var builtinFS embed.FS

func builtinCourses() []string {
	entries, _ := builtinFS.ReadDir("builtin")
	var names []string
	for _, e := range entries {
		if e.IsDir() {
			names = append(names, e.Name())
		}
	}
	return names
}

// addBuiltin writes a built-in course into the workspace: its files into
// <name>/ and its track into tracks/<name>.toml. Files that already exist are
// left alone, so answers survive and exercises added later still appear.
func addBuiltin(w *Workspace, name string) error {
	root := "builtin/" + name
	return fs.WalkDir(builtinFS, root, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		rel := strings.TrimPrefix(path, root+"/")
		dst := filepath.Join(w.dir, name, filepath.FromSlash(rel))
		if rel == "track.toml" {
			dst = filepath.Join(w.tracksDir(), name+".toml")
		} else if _, err := os.Stat(dst); err == nil {
			return nil
		}
		data, err := builtinFS.ReadFile(path)
		if err != nil {
			return err
		}
		if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
			return err
		}
		return os.WriteFile(dst, data, 0o644)
	})
}

// builtinOriginal returns an exercise as it ships, if its track is built in.
func builtinOriginal(t *Track, ex *Exercise) ([]byte, bool) {
	data, err := builtinFS.ReadFile("builtin/" + t.id + "/" + filepath.ToSlash(ex.File))
	return data, err == nil
}
