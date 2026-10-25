// langlings is one exercise runner for every language. Languages are described by
// tracks/<name>.toml files; this program only watches, checks and tracks
// progress.
package main

import (
	"fmt"
	"os"
	"os/signal"
	"runtime"
	"sync"
	"syscall"
)

const usage = `langlings: one runner for fix-the-code exercises in any language

usage:
  langlings [track]                work through a track, re-checking on every save
                                   (no track: resume the last one, or pick from a list)
  langlings list [track]           show tracks, or the exercises in one track
  langlings hint [track]           show the hint for the current exercise
  langlings run [track] [name]     check one exercise once (default: the current one)
  langlings verify [track]         check every exercise and update progress
  langlings reset [track] [name]   restore an exercise from git (default: the current one)
  langlings add [course]           set up a course and its track (no course: list them)
  langlings import rustlings DIR   generate tracks/rustlings.toml from a rustlings folder
  langlings import ziglings DIR    generate tracks/ziglings.toml from a ziglings folder
`

func main() {
	// On Ctrl-C, give the terminal back. A running exercise gets the same
	// Ctrl-C from the terminal and stops by itself.
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sigs
		restoreTerminal()
		fmt.Println()
		os.Exit(130)
	}()

	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "langlings:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	cmd, rest := "watch", args
	if len(args) > 0 {
		cmd, rest = args[0], args[1:]
	}
	arg := func(i int) string {
		if i < len(rest) {
			return rest[i]
		}
		return ""
	}

	switch cmd {
	case "help", "-h", "--help":
		fmt.Print(usage)
		if w, err := openWorkspace(); err == nil {
			fmt.Print("\ntracks here:\n")
			printTracks(w, false)
		}
		return nil
	case "add":
		if len(rest) == 0 {
			fmt.Print(courseList())
			return nil
		}
		return addCourse(rest[0])
	case "import":
		if len(rest) != 2 {
			return fmt.Errorf("usage: langlings import rustlings|ziglings DIR")
		}
		return importCourse(rest[0], rest[1])
	}

	w, err := openWorkspace()
	if err != nil {
		return err
	}

	switch cmd {
	case "watch":
		// No track named and none used before: watch starts at the picker.
		t, err := w.track(arg(0))
		if err != nil && arg(0) != "" {
			return err
		}
		return watch(w, t)

	case "list":
		if arg(0) == "" {
			printTracks(w, false)
			return nil
		}
		t, err := w.track(arg(0))
		if err != nil {
			return err
		}
		printExercises(w, t)
		return nil

	case "hint":
		t, err := w.track(arg(0))
		if err != nil {
			return err
		}
		if ex := w.current(t); ex != nil {
			fmt.Printf("%s:\n", ex.Name)
			printHint(ex)
		}
		return nil

	case "run", "reset":
		t, err := w.track(arg(0))
		if err != nil {
			return err
		}
		ex := w.current(t)
		if arg(1) != "" {
			ex = t.find(arg(1))
		}
		if ex == nil {
			return fmt.Errorf("no such exercise")
		}
		if cmd == "reset" {
			if err := w.reset(t, ex); err != nil {
				return err
			}
			fmt.Printf("restored %s\n", displayPath(t, ex.File))
			return nil
		}
		res := check(t, ex)
		fmt.Print(res.Output)
		if !res.Passed {
			return fmt.Errorf("%s: %s", ex.Name, res.Reason)
		}
		w.progress.setDone(t.id, ex.Name, true)
		fmt.Printf("%s✓ %s passed%s\n", green, ex.Name, reset)
		return w.progress.save()

	case "verify":
		t, err := w.track(arg(0))
		if err != nil {
			return err
		}
		return verify(w, t)

	default:
		// `langlings ziglings` is short for `langlings watch ziglings`.
		if t, ok := w.tracks[cmd]; ok {
			return watch(w, t)
		}
		return fmt.Errorf("unknown command or track %q\n\n%s", cmd, usage)
	}
}

// printTracks shows every track with its progress and what comes next.
func printTracks(w *Workspace, numbered bool) {
	for i, id := range w.trackIDs() {
		t := w.tracks[id]
		next := green + "done" + reset
		if ex := w.current(t); ex != nil {
			next = "next: " + ex.Name
		}
		num := ""
		if numbered {
			num = fmt.Sprintf("%d  ", i+1)
		}
		fmt.Printf("  %s%-14s %3d/%-4d %s\n", num, id, w.progress.count(t), len(t.Exercises), next)
	}
}

func printExercises(w *Workspace, t *Track) {
	cur := w.current(t)
	for i := range t.Exercises {
		ex := &t.Exercises[i]
		mark := "  "
		switch {
		case ex == cur:
			mark = "→ "
		case ex.Skip:
			mark = "- "
		case w.progress.isDone(t.id, ex.Name):
			mark = green + "✓ " + reset
		}
		fmt.Printf("%s%s\n", mark, ex.Name)
	}
	fmt.Printf("\n%d/%d done\n", w.progress.count(t), len(t.Exercises))
}

// verify checks every exercise in parallel and records what actually passes,
// which is handy after editing exercises outside of `langlings`.
func verify(w *Workspace, t *Track) error {
	results := make([]Result, len(t.Exercises))
	jobs := make(chan int)
	var wg sync.WaitGroup
	for range runtime.NumCPU() {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range jobs {
				results[i] = check(t, &t.Exercises[i])
				fmt.Print(".")
			}
		}()
	}
	for i := range t.Exercises {
		if !t.Exercises[i].Skip {
			jobs <- i
		}
	}
	close(jobs)
	wg.Wait()
	fmt.Println()

	failed := 0
	for i, ex := range t.Exercises {
		if ex.Skip {
			continue
		}
		w.progress.setDone(t.id, ex.Name, results[i].Passed)
		if !results[i].Passed {
			failed++
			fmt.Printf("%s✗ %s%s\n", red, ex.Name, reset)
		}
	}
	fmt.Printf("%d/%d passing\n", w.progress.count(t), len(t.Exercises))
	if failed > 0 {
		fmt.Printf("Run `langlings run %s NAME` to see why one fails.\n", t.id)
	}
	return w.progress.save()
}
