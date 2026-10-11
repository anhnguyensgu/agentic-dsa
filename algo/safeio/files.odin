// Package safeio holds the OS interactions the practice tools share where a
// mistake would leak credentials or learner data: owner-only atomic file
// writes and bounded child processes with a scrubbed environment.
package safeio

import "core:os"
import "core:strings"

// write_private_file atomically replaces path with data, readable only by the
// owner (0600). Missing parent directories are created with 0700.
//
// The data goes to a private sibling first and is renamed over the target, so
// a failed write leaves the previous contents intact and a symlink at path is
// replaced rather than followed.
write_private_file :: proc(path: string, data: []byte) -> (err: os.Error) {
	dir := os.dir(path)
	if mkdir_err := os.make_directory_all(dir, os.perm(0o700)); mkdir_err != nil && mkdir_err != .Exist {
		return mkdir_err
	}

	file := os.create_temp_file(dir, ".safeio-write-*") or_return
	// os.name borrows the File's storage, which close frees; the deferred
	// remove needs its own copy.
	temporary := strings.clone(os.name(file), context.temp_allocator)
	defer os.remove(temporary)
	defer if file != nil {
		os.close(file)
	}

	os.fchmod(file, os.perm(0o600)) or_return
	written := os.write(file, data) or_return
	if written != len(data) {
		return .Short_Write
	}
	err = os.close(file)
	file = nil
	if err != nil {
		return
	}
	return os.rename(temporary, path)
}
