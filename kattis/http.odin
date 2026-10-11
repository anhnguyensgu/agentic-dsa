package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// A real-browser agent: Kattis/Cloudflare stall or reject bot-pattern agents
// in some regions. -4 avoids IPv6 paths that silently black-hole requests.
USER_AGENT :: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

// curl runs curl with the shared transport flags followed by args and returns
// its stdout. No shell is involved; secrets travel through files, never argv.
curl :: proc(args: ..string) -> (output: string, err: Error) {
	command := make([dynamic]string)
	append(&command, "curl", "-q", "-sS", "-4", "-A", USER_AGENT, "--connect-timeout", "10")
	append(&command, ..args)
	state, stdout, stderr, exec_err := os.process_exec({command = command[:]}, context.allocator)
	if exec_err != nil || state.exit_code != 0 {
		fmt.eprintf("curl failed (exit %d): %s\n", state.exit_code, strings.trim_space(string(stderr)))
		return "", .Network
	}
	return string(stdout), nil
}

http_get :: proc(url: string) -> (body: string, err: Error) {
	return curl("-L", "--max-time", "30", "--url", url)
}

// http_get_session fetches url with the saved session and returns the final
// status after redirects. Kattis redirects anonymous requests for private
// pages to /login; that is reported as 401.
http_get_session :: proc(url: string) -> (body: string, status: int, err: Error) {
	jar := session_path() or_return
	output := curl("-L", "-b", jar, "--max-time", "30", "--url", url, "--write-out", `\n%{http_code} %{url_effective}`) or_return

	newline := strings.last_index(output, "\n")
	if newline < 0 {
		return "", 0, .Network
	}
	code, final_url := split_once(output[newline + 1:], " ")
	if strings.contains(final_url, "/login") {
		return "", 401, nil
	}
	return output[:newline], strconv.parse_int(code) or_else 0, nil
}

// The session cookie jar. The directory name predates the rename to
// kattis-odin and is kept so existing logins keep working.
session_path :: proc() -> (path: string, err: Error) {
	home, home_err := os.user_home_dir(context.allocator)
	if home_err != nil {
		fmt.eprintln("cannot resolve the home directory")
		return "", .File
	}
	return join(home, ".config", "kattis-poc", "session"), nil
}

join :: proc(parts: ..string) -> string {
	return os.join_path(parts, context.allocator) or_else ""
}

split_once :: proc(s, sep: string) -> (head, tail: string) {
	i := strings.index(s, sep)
	if i < 0 {
		return s, ""
	}
	return s[:i], s[i + len(sep):]
}

print_json :: proc(v: any) {
	data, err := json.marshal(v)
	assert(err == nil, "report types must be marshalable")
	fmt.println(string(data))
}
