package main

import (
	"bufio"
	"os"

	"github.com/mattn/go-tty"
)

// restoreTerminal gives the terminal back. It's a no-op until readKeys runs.
var restoreTerminal = func() {}

// readKeys delivers each key as soon as it's pressed. go-tty switches the
// terminal so keys arrive without Enter and aren't echoed, on every OS, while
// output and Ctrl-C keep working. Without a terminal (piped input) it reads
// stdin instead. The channel closes when input ends.
func readKeys() <-chan rune {
	stdin := bufio.NewReader(os.Stdin)
	read := func() (rune, error) {
		r, _, err := stdin.ReadRune()
		return r, err
	}
	if t, err := tty.Open(); err == nil {
		read = t.ReadRune
		restoreTerminal = func() { t.Close() }
	}

	keys := make(chan rune)
	go func() {
		for {
			r, err := read()
			if err != nil {
				close(keys)
				return
			}
			keys <- r
		}
	}()
	return keys
}
