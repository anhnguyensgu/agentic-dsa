package main

// Script-free e-mail login, mirroring the browser's "Log in with e-mail" form:
//   1. GET  /login/email     sets the session cookie and hands out a csrf_token
//   2. POST user, password, and csrf_token back to /login/email
//   3. follow the redirect so every Set-Cookie lands in the jar
// The older /login?script=true endpoint expects an API token, not the UI
// password. SSO-only accounts (GitHub etc.) are not supported.

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"
import "../safeio"

LOGIN_ATTEMPTS :: 3

cmd_auth :: proc(user: string) -> Error {
	stdin, read_err := os.read_entire_file(os.stdin, context.allocator)
	password := strings.trim_space(string(stdin))
	if read_err != nil || password == "" {
		fmt.eprintln("no password on stdin (echo <password> | kattis auth <user>)")
		return .Usage
	}
	jar := session_path() or_return
	if err := os.make_directory_all(os.dir(jar), os.perm(0o700)); err != nil && err != .Exist {
		fmt.eprintln("cannot create", os.dir(jar), os.error_string(err))
		return .File
	}
	login_url := fmt.tprintf("%s/login/email", BASE_URL)

	form := curl("--max-time", "45", "-c", jar, "--url", login_url) or_return
	csrf, _ := between(form, `name="csrf_token" value="`, `"`)
	if csrf == "" {
		fmt.eprintln("the login form has no csrf token")
		return .Markup_Changed
	}

	// The password travels through a private file (curl's name@file form of
	// --data-urlencode), never argv, shell history, or an unencoded body.
	password_path := strings.concatenate({jar, ".password"})
	if safeio.write_private_file(password_path, transmute([]byte)password) != nil {
		fmt.eprintln("cannot write the private password file")
		return .File
	}
	defer os.remove(password_path)

	// Cloudflare sometimes stalls POSTs; a few attempts ride out transient drops.
	response: string
	for attempt in 1 ..= LOGIN_ATTEMPTS {
		post_err: Error
		response, post_err = curl(
			"--max-time", "45",
			"-b", jar,
			"-c", jar,
			"--data-urlencode", strings.concatenate({"user=", user}),
			"--data-urlencode", strings.concatenate({"password@", password_path}),
			"--data-urlencode", strings.concatenate({"csrf_token=", csrf}),
			"--url", login_url,
			"--write-out", `\n%{http_code}`,
		)
		if post_err == nil {
			break
		}
		if attempt == LOGIN_ATTEMPTS {
			return post_err
		}
		fmt.eprintf("login attempt %d failed; retrying...\n", attempt)
		time.sleep(2 * time.Second)
	}

	newline := max(strings.last_index(response, "\n"), 0)
	body := strings.trim_space(response[:newline])
	status := strconv.parse_int(strings.trim_space(response[newline:])) or_else 0
	switch {
	case status == 200 && strings.contains(body, "Unknown Username/Password"):
		fmt.eprintln("unknown username or password; the same pair must work via 'Log in with e-mail' in a browser")
		return .Login_Failed
	case status < 300 || status >= 400: // success is a redirect
		fmt.eprintln("Kattis did not redirect after the form post:")
		fmt.eprintln(body[:min(len(body), 300)])
		return .Login_Failed
	}

	curl("-L", "--max-time", "45", "-b", jar, "-c", jar, "--url", fmt.tprintf("%s/", BASE_URL)) or_return
	if !session_alive() {
		fmt.eprintln("Kattis did not accept the saved session; if this persists, the network or IP may be blocked")
		return .Login_Failed
	}
	fmt.printf("signed in as %s; session saved at %s\n", user, jar)
	return nil
}

// Anonymous pages carry a "Log in" link; signed-in pages show the username.
session_alive :: proc() -> bool {
	body, status, err := http_get_session(fmt.tprintf("%s/", BASE_URL))
	return err == nil && status == 200 && !strings.contains(body, `href="/login"`)
}
