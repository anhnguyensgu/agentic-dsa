package kattis

import judge ".."
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// A real-browser agent: Kattis/Cloudflare stall or reject bot-pattern agents
// in some regions. -4 avoids IPv6 paths that silently black-hole requests.
USER_AGENT :: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

// curl adds the Kattis transport flags to the shared judge transport.
curl :: proc(args: ..string) -> (output: string, err: Error) {
	command := make([dynamic]string)
	append(&command, "-4", "-A", USER_AGENT)
	append(&command, ..args)
	return judge.curl(..command[:])
}

http_get :: proc(url: string) -> (body: string, err: Error) {
	return curl("-L", "--max-time", "30", "--url", url)
}

// http_get_session fetches url with the saved session and returns the final
// status after redirects. Kattis redirects anonymous requests for private
// pages to /login; that is reported as 401.
http_get_session :: proc(url: string) -> (body: string, status: int, err: Error) {
	jar := session_path() or_return
	output := curl(
		"-L",
		"-b",
		jar,
		"--max-time",
		"30",
		"--url",
		url,
		"--write-out",
		`\n%{http_code} %{url_effective}`,
	) or_return

	page, trailer, ok := judge.split_trailer(output)
	if !ok {
		return "", 0, .Network
	}
	code, final_url := judge.split_once(trailer, " ")
	if strings.contains(final_url, "/login") {
		return "", 401, nil
	}
	return page, strconv.parse_int(code) or_else 0, nil
}

// The session cookie jar; KATTIS_ODIN_SESSION overrides it. The directory
// name predates the rename to kattis-odin and is kept so existing logins keep
// working.
session_path :: proc() -> (path: string, err: Error) {
	if override := os.get_env("KATTIS_ODIN_SESSION", context.allocator); override != "" {
		return override, nil
	}
	home, home_err := os.user_home_dir(context.allocator)
	if home_err != nil {
		fmt.eprintln("cannot resolve the home directory")
		return "", .File
	}
	return judge.join(home, ".config", "kattis-poc", "session"), nil
}
