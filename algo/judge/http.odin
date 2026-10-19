package judge

import "../safeio"
import "core:fmt"
import "core:os"
import "core:strings"

// curl runs curl with the shared transport flags followed by args and returns
// its stdout. No shell is involved, and secrets never travel in argv: callers
// pass headers, bodies, and passwords as files from private_dir (curl's
// @file forms) or a cookie jar.
curl :: proc(args: ..string) -> (output: string, err: Error) {
	command := make([dynamic]string)
	append(&command, "curl", "-q", "-sS", "--connect-timeout", "10")
	append(&command, ..args)
	state, stdout, stderr, exec_err := os.process_exec({command = command[:]}, context.allocator)
	if exec_err != nil || state.exit_code != 0 {
		// curl's error text never contains request headers or response bodies.
		fmt.eprintf(
			"curl failed (exit %d): %s\n",
			state.exit_code,
			strings.trim_space(string(stderr)),
		)
		return "", .Network
	}
	return string(stdout), nil
}

// split_trailer splits curl output at its final newline into the response
// body and the --write-out trailer (e.g. "\n%{http_code}"). Without a newline
// the whole output is the trailer and ok is false.
split_trailer :: proc(output: string) -> (body, trailer: string, ok: bool) {
	newline := strings.last_index(output, "\n")
	if newline < 0 {
		return "", output, false
	}
	return output[:newline], output[newline + 1:], true
}

// private_dir creates an owner-only temporary directory for request files.
// The caller removes it with os.remove_all.
private_dir :: proc(pattern: string) -> (dir: string, err: Error) {
	created, dir_err := os.make_directory_temp("", pattern, context.allocator)
	if dir_err != nil {
		return "", .File
	}
	if os.chmod(created, os.perm(0o700)) != nil {
		os.remove_all(created)
		return "", .File
	}
	return created, nil
}

// write_secret writes data to dir/name with owner-only permissions and
// returns the path, ready for curl's @file forms.
write_secret :: proc(dir, name, data: string) -> (path: string, err: Error) {
	path = join(dir, name)
	if safeio.write_private_file(path, transmute([]byte)data) != nil {
		fmt.eprintln("cannot write the private request file", name)
		return "", .File
	}
	return path, nil
}

// url_encode encodes a query-string value: unreserved characters pass
// through, space becomes '+', and everything else becomes %XX.
url_encode :: proc(s: string) -> string {
	hex := "0123456789ABCDEF"
	b := strings.builder_make()
	for i in 0 ..< len(s) {
		switch c := s[i]; c {
		case 'a' ..= 'z', 'A' ..= 'Z', '0' ..= '9', '-', '_', '.', '~':
			strings.write_byte(&b, c)
		case ' ':
			strings.write_byte(&b, '+')
		case:
			strings.write_byte(&b, '%')
			strings.write_byte(&b, hex[c >> 4])
			strings.write_byte(&b, hex[c & 0xf])
		}
	}
	return strings.to_string(b)
}
