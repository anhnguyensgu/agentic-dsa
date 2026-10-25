package main

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os/exec"
	"strings"
	"sync"
	"time"
)

const checkTimeout = 2 * time.Minute

type Result struct {
	Passed bool
	Output string // everything the program printed, in order
	Reason string // why it failed, empty when passed
}

// check runs one exercise. It passes when every command exits 0 and, if the
// exercise sets `expect`, the chosen output stream matches it.
func check(t *Track, ex *Exercise) Result {
	steps := t.commands(ex)
	if len(steps) == 0 {
		return Result{Reason: "nothing to run: set `run` in the track or `cmd` on the exercise"}
	}
	ctx, cancel := context.WithTimeout(context.Background(), checkTimeout)
	defer cancel()

	var stdout, stderr bytes.Buffer
	var combined lockedBuffer
	var err error
	for _, args := range steps {
		cmd := exec.CommandContext(ctx, args[0], args[1:]...)
		cmd.Dir = t.dir
		cmd.Stdout = io.MultiWriter(&stdout, &combined)
		cmd.Stderr = io.MultiWriter(&stderr, &combined)
		// After a timeout, don't wait on children that still hold the output.
		cmd.WaitDelay = time.Second
		if err = cmd.Run(); err != nil {
			break
		}
	}

	res := Result{Output: combined.String()}
	switch {
	case ctx.Err() != nil:
		res.Reason = fmt.Sprintf("timed out after %s (infinite loop?)", checkTimeout)
	case err != nil:
		res.Reason = err.Error()
	case ex.Expect != "":
		got := stdout.String()
		if t.stream(ex) == "stderr" {
			got = stderr.String()
		}
		if normalize(got) != normalize(ex.Expect) {
			res.Reason = fmt.Sprintf("wrong output\n--- expected ---\n%s\n--- got ---\n%s",
				normalize(ex.Expect), normalize(got))
		}
	}
	res.Passed = res.Reason == ""
	return res
}

// normalize ignores trailing spaces on each line and trailing blank lines.
func normalize(s string) string {
	lines := strings.Split(s, "\n")
	for i, l := range lines {
		lines[i] = strings.TrimRight(l, " \r\t")
	}
	return strings.TrimRight(strings.Join(lines, "\n"), "\n")
}

// lockedBuffer lets stdout and stderr be copied into one buffer concurrently.
type lockedBuffer struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (b *lockedBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.Write(p)
}

func (b *lockedBuffer) String() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.String()
}
