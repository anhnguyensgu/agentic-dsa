package judge

import "core:fmt"
import "core:os"
import "core:strings"

// Owner-only mode for credentials, caches, and learner workspaces.
PRIVATE_FILE :: os.Permissions{.Read_User, .Write_User}

// The core:os default: owner read-write, everyone else read-only.
PUBLIC_FILE :: os.Permissions_Read_All + {.Write_User}

join :: proc(parts: ..string) -> string {
	return os.join_path(parts, context.allocator) or_else ""
}

concat :: proc(parts: ..string) -> string {
	return strings.concatenate(parts) or_else ""
}

split_once :: proc(s, sep: string) -> (head, tail: string) {
	i := strings.index(s, sep)
	if i < 0 {
		return s, ""
	}
	return s[:i], s[i + len(sep):]
}

digits :: proc(s: string) -> bool {
	if s == "" {
		return false
	}
	for c in s {
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}

// write_file writes data to path, printing the cause on failure.
write_file :: proc(path, data: string, perm := PRIVATE_FILE) -> Error {
	if err := os.write_entire_file(path, data, perm); err != nil {
		fmt.eprintf("%s: %s\n", path, os.error_string(err))
		return .File
	}
	return nil
}
