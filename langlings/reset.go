package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// reset puts an exercise back the way it shipped and marks it unfinished.
// Built-in courses carry their originals inside langlings; for the others,
// git already keeps them. Either way langlings stores no copies.
func (w *Workspace) reset(t *Track, ex *Exercise) error {
	path := filepath.Join(t.dir, ex.File)
	if data, ok := builtinOriginal(t, ex); ok {
		if err := os.WriteFile(path, data, 0o644); err != nil {
			return err
		}
	} else {
		cmd := exec.Command("git", "restore", "--source=HEAD", "--", filepath.Base(path))
		cmd.Dir = filepath.Dir(path)
		if out, err := cmd.CombinedOutput(); err != nil {
			return fmt.Errorf("can't reset %s: reset restores the version committed in git, and git said: %s",
				ex.Name, strings.TrimSpace(string(out)))
		}
	}
	w.progress.setDone(t.id, ex.Name, false)
	return w.progress.save()
}
