package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/BurntSushi/toml"
)

// Track is one course, loaded from tracks/<id>.toml. Everything that differs
// between languages lives here, so the engine never needs to know about them.
type Track struct {
	Root      string     `toml:"root"`   // directory commands run in, relative to the track file
	Run       string     `toml:"run"`    // command for mode = "run"; {file} and {name} are substituted
	Test      string     `toml:"test"`   // command for mode = "test"
	Stream    string     `toml:"stream"` // output `expect` is compared to: "stdout" (default) or "stderr"
	Exercises []Exercise `toml:"exercise"`

	id  string // file name without .toml
	dir string // absolute path of Root
}

type Exercise struct {
	Name   string `toml:"name"`
	File   string `toml:"file"`
	Mode   string `toml:"mode"`   // "run" (default) or "test"
	Cmd    string `toml:"cmd"`    // replaces the track's run/test command
	Stream string `toml:"stream"` // overrides the track's stream
	Readme string `toml:"readme"` // problem statement to read first
	Expect string `toml:"expect"` // required output, if any
	Hint   string `toml:"hint"`
	Skip   bool   `toml:"skip"`
}

// commands returns the steps that check an exercise. They run directly, not
// through a shell, so a track works the same on every OS; && separates steps.
// Placeholders are filled in after splitting, so paths with spaces are safe.
func (t *Track) commands(ex *Exercise) [][]string {
	cmd := ex.Cmd
	if cmd == "" && ex.Mode == "test" {
		cmd = t.Test
	}
	if cmd == "" {
		cmd = t.Run
	}
	fill := strings.NewReplacer("{file}", ex.File, "{name}", ex.Name)
	var steps [][]string
	for _, step := range strings.Split(cmd, "&&") {
		args := strings.Fields(step)
		for i := range args {
			args[i] = fill.Replace(args[i])
		}
		if len(args) > 0 {
			steps = append(steps, args)
		}
	}
	return steps
}

func (t *Track) stream(ex *Exercise) string {
	if ex.Stream != "" {
		return ex.Stream
	}
	if t.Stream != "" {
		return t.Stream
	}
	return "stdout"
}

func (t *Track) find(name string) *Exercise {
	for i := range t.Exercises {
		if t.Exercises[i].Name == name {
			return &t.Exercises[i]
		}
	}
	return nil
}

// Workspace is the directory holding tracks/ and the progress file.
type Workspace struct {
	dir      string
	tracks   map[string]*Track
	progress *Progress
}

func (w *Workspace) tracksDir() string { return filepath.Join(w.dir, "tracks") }

// openWorkspace walks up from the current directory until it finds tracks/,
// the same way git looks for .git.
func openWorkspace() (*Workspace, error) {
	dir, err := os.Getwd()
	if err != nil {
		return nil, err
	}
	for {
		if info, err := os.Stat(filepath.Join(dir, "tracks")); err == nil && info.IsDir() {
			break
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return nil, errors.New("no tracks/ directory found here or in any parent")
		}
		dir = parent
	}

	w := &Workspace{dir: dir, tracks: map[string]*Track{}}
	files, _ := filepath.Glob(filepath.Join(w.tracksDir(), "*.toml"))
	for _, f := range files {
		t := &Track{}
		if _, err := toml.DecodeFile(f, t); err != nil {
			return nil, fmt.Errorf("%s: %w", f, err)
		}
		t.id = strings.TrimSuffix(filepath.Base(f), ".toml")
		t.dir = t.Root
		if !filepath.IsAbs(t.dir) {
			t.dir = filepath.Join(w.tracksDir(), t.Root)
		}
		w.tracks[t.id] = t
	}

	w.progress, err = loadProgress(filepath.Join(dir, ".langlings", "progress.json"))
	return w, err
}

func (w *Workspace) trackIDs() []string {
	ids := make([]string, 0, len(w.tracks))
	for id := range w.tracks {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	return ids
}

// track resolves a track name, falling back to the one used last.
func (w *Workspace) track(id string) (*Track, error) {
	if id == "" {
		id = w.progress.Last
	}
	if id == "" && len(w.tracks) == 1 {
		id = w.trackIDs()[0]
	}
	if id == "" {
		return nil, fmt.Errorf("pick a track: %s", strings.Join(w.trackIDs(), ", "))
	}
	t, ok := w.tracks[id]
	if !ok {
		return nil, fmt.Errorf("no track %q (have: %s)", id, strings.Join(w.trackIDs(), ", "))
	}
	return t, nil
}

// current is the first exercise in the track that isn't done or skipped.
func (w *Workspace) current(t *Track) *Exercise {
	for i := range t.Exercises {
		ex := &t.Exercises[i]
		if !ex.Skip && !w.progress.isDone(t.id, ex.Name) {
			return ex
		}
	}
	return nil
}
