package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	red         = "\033[31m"
	green       = "\033[32m"
	dim         = "\033[2m"
	reset       = "\033[0m"
	clearScreen = "\033[H\033[2J"
)

// watch is the interactive mode. Without a track it starts at the track
// picker, and t returns there from any exercise.
func watch(w *Workspace, t *Track) error {
	if len(w.tracks) == 0 {
		return fmt.Errorf("no tracks yet: add tracks/<name>.toml or run `langlings import`")
	}
	keys := readKeys()
	defer restoreTerminal()
	for {
		if t == nil {
			if t = pickTrack(w, keys); t == nil {
				return nil
			}
		}
		pick, err := work(w, t, keys)
		if err != nil || !pick {
			return err
		}
		t = nil
	}
}

func pickTrack(w *Workspace, keys <-chan rune) *Track {
	ids := w.trackIDs()
	fmt.Print(clearScreen)
	fmt.Print("Tracks\n\n")
	printTracks(w, true)
	fmt.Printf("\n%sPress 1-%d to start · q: quit%s\n", dim, len(ids), reset)
	for key := range keys {
		if key == 'q' {
			return nil
		}
		if n := int(key) - '1'; n >= 0 && n < len(ids) {
			return w.tracks[ids[n]]
		}
	}
	return nil
}

// work goes through one track: check the current exercise, re-check every
// time its file is saved, and move on when it passes and the learner says so.
// It reports whether the learner asked to pick another track.
func work(w *Workspace, t *Track, keys <-chan rune) (pick bool, err error) {
	w.progress.Last = t.id
	if err := w.progress.save(); err != nil {
		return false, err
	}

	ex := w.current(t)
	for ex != nil {
		path := filepath.Join(t.dir, ex.File)
		fmt.Print(clearScreen)
		fmt.Printf("%sChecking %s…%s\n", dim, ex.Name, reset)
		res := check(t, ex)

		fmt.Print(clearScreen)
		fmt.Print(res.Output)
		if res.Passed {
			w.progress.setDone(t.id, ex.Name, true)
			if err := w.progress.save(); err != nil {
				return false, err
			}
			fmt.Printf("\n%s✓ %s passed%s\n", green, ex.Name, reset)
		} else {
			fmt.Printf("\n%s✗ %s%s\n", red, res.Reason, reset)
		}
		printHeader(w, t, ex)
		if res.Passed {
			fmt.Printf("%sEnter: next · h: hint · l: list · t: tracks · q: quit%s\n", dim, reset)
		} else {
			fmt.Printf("%sSave the file to re-check · h: hint · l: list · t: tracks · q: quit%s\n", dim, reset)
		}

		before := modTime(path)
		ticker := time.NewTicker(300 * time.Millisecond)
	wait:
		for {
			select {
			case key, ok := <-keys:
				if !ok {
					keys = nil // stdin closed; keep watching the file
					continue
				}
				switch key {
				case 'q', 't':
					ticker.Stop()
					return key == 't', nil
				case 'h':
					printHint(ex)
				case 'l':
					printExercises(w, t)
				case 'r':
					break wait
				case '\n', '\r', 'n':
					if res.Passed {
						ex = w.current(t)
						break wait
					}
					fmt.Println("Not passing yet. Fix the file and save it.")
				}
			case <-ticker.C:
				if modTime(path) != before {
					break wait
				}
			}
		}
		ticker.Stop()
	}

	fmt.Print(clearScreen)
	fmt.Printf("%s🎉 You finished every exercise in %s!%s\n", green, t.id, reset)
	fmt.Printf("%st: tracks · q: quit%s\n", dim, reset)
	if keys == nil {
		return false, nil
	}
	for key := range keys {
		if key == 'q' || key == 't' {
			return key == 't', nil
		}
	}
	return false, nil
}

func printHeader(w *Workspace, t *Track, ex *Exercise) {
	fmt.Printf("\n[%s %d/%d] %s → %s\n", t.id, w.progress.count(t), len(t.Exercises), ex.Name, displayPath(t, ex.File))
	if ex.Readme != "" {
		fmt.Printf("Read: %s\n", displayPath(t, ex.Readme))
	}
}

func printHint(ex *Exercise) {
	if ex.Hint == "" {
		fmt.Println("No hint for this one. Read the comments in the file and the compiler output.")
		return
	}
	fmt.Printf("\n%s\n\n", strings.TrimSpace(ex.Hint))
}

// displayPath shows a file relative to where the learner is when that's
// shorter, so editors and terminals can open it with a click.
func displayPath(t *Track, file string) string {
	abs := filepath.Join(t.dir, file)
	if cwd, err := os.Getwd(); err == nil {
		if rel, err := filepath.Rel(cwd, abs); err == nil && len(rel) < len(abs) {
			return rel
		}
	}
	return abs
}

func modTime(path string) time.Time {
	info, err := os.Stat(path)
	if err != nil {
		return time.Time{}
	}
	return info.ModTime()
}
