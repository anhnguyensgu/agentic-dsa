// One-shot, loopback-only HTTP callback for browser login.
package leetcode

import judge ".."
import "core:fmt"
import "core:net"
import "core:os"
import "core:strings"
import "core:time"

CALLBACK_HOST :: "127.0.0.1"
CALLBACK_PORT :: 9777
CALLBACK_TIMEOUT :: 2 * time.Minute

capture_callback :: proc(url: string) -> (cfg: Config, err: Error) {
	ep := net.Endpoint {
		address = net.IP4_Loopback,
		port    = CALLBACK_PORT,
	}
	sock, listen_err := net.listen_tcp(ep)
	if listen_err != nil {
		fmt.eprintf("failed to listen on %s:%d: %v\n", CALLBACK_HOST, CALLBACK_PORT, listen_err)
		return {}, .Callback_Failed
	}
	defer net.close(sock)

	open_browser(url)
	fmt.printf(
		"waiting for the browser callback (up to %d seconds) ...\n",
		int(CALLBACK_TIMEOUT / time.Second),
	)
	started := time.tick_now()
	client := accept_callback(sock, CALLBACK_TIMEOUT) or_return
	defer net.close(client)

	buffer: [8192]byte
	req := read_http_request(
		client,
		buffer[:],
		CALLBACK_TIMEOUT - time.tick_since(started),
	) or_return
	query := extract_query(req)
	if query == "" {
		fmt.eprintln("expected a complete HTTP GET callback with a query string")
		return {}, .Callback_Failed
	}

	cfg = extract_cookies(query) or_return
	respond_ok(client)
	return cfg, nil
}

// SO_RCVTIMEO does not time out accept() on macOS. Poll a nonblocking
// listener with a monotonic deadline instead; this server handles one client.
accept_callback :: proc(
	sock: net.TCP_Socket,
	timeout: time.Duration,
) -> (
	client: net.TCP_Socket,
	err: Error,
) {
	if block_err := net.set_blocking(sock, false); block_err != nil {
		fmt.eprintln("failed to make callback listener nonblocking:", block_err)
		return {}, .Callback_Failed
	}

	started := time.tick_now()
	for time.tick_since(started) < timeout {
		accepted, _, accept_err := net.accept_tcp(sock)
		if accept_err == nil {
			return accepted, nil
		}
		if accept_err != .Would_Block && accept_err != .Interrupted {
			fmt.eprintln("failed to accept browser callback:", accept_err)
			return {}, .Callback_Failed
		}
		remaining := timeout - time.tick_since(started)
		if remaining > 0 {
			time.sleep(min(remaining, 10 * time.Millisecond))
		}
	}
	fmt.eprintln("timed out waiting for the browser callback")
	return {}, .Callback_Failed
}

// Best effort: the printed URL remains available if launching a browser fails.
open_browser :: proc(url: string) {
	fmt.println("open this URL in your browser if it does not open by itself:")
	fmt.println(" ", url)
	if os.get_env("LEETCODE_ODIN_NO_BROWSER", context.temp_allocator) != "" {
		return
	}

	browser := "xdg-open"
	when ODIN_OS == .Darwin {
		browser = "open"
	}
	state, stdout, stderr, err := os.process_exec({command = {browser, url}}, context.allocator)
	defer delete(stdout)
	defer delete(stderr)
	if err != nil {
		fmt.eprintln("could not open browser automatically:", os.error_string(err))
	} else if state.exit_code != 0 {
		fmt.eprintln("browser launcher failed:", string(stderr))
	}
}

// Returns a view into buffer only after complete headers arrive. EOF, timeout
// and oversized/incomplete headers are failures, never partial successes.
read_http_request :: proc(
	client: net.TCP_Socket,
	buffer: []byte,
	timeout: time.Duration,
) -> (
	req: string,
	err: Error,
) {
	if block_err := net.set_blocking(client, true); block_err != nil {
		return "", .Callback_Failed
	}
	started := time.tick_now()
	total := 0
	for total < len(buffer) {
		remaining := timeout - time.tick_since(started)
		if remaining <= 0 {
			fmt.eprintln("timed out reading callback headers")
			return "", .Callback_Failed
		}
		// Avoid rounding a sub-microsecond duration down to an infinite timeout.
		if option_err := net.set_option(
			client,
			.Receive_Timeout,
			max(remaining, time.Millisecond),
		); option_err != nil {
			fmt.eprintln("failed to set callback receive timeout:", option_err)
			return "", .Callback_Failed
		}
		n, recv_err := net.recv(client, buffer[total:])
		if recv_err == .Interrupted {
			continue
		}
		if recv_err != nil || n == 0 {
			fmt.eprintln("callback closed or timed out before completing its headers")
			return "", .Callback_Failed
		}
		total += n
		if end := strings.index(string(buffer[:total]), "\r\n\r\n"); end >= 0 {
			return string(buffer[:end + 4]), nil
		}
	}
	fmt.eprintln("callback headers exceed the buffer limit")
	return "", .Callback_Failed
}

// The result borrows req. Only origin-form HTTP/1.x GET targets are accepted.
extract_query :: proc(req: string) -> string {
	if !strings.contains(req, "\r\n\r\n") {
		return ""
	}
	line, _ := judge.split_once(req, "\r\n")
	method, rest := judge.split_once(line, " ")
	target, version := judge.split_once(rest, " ")
	if method != "GET" ||
	   (version != "HTTP/1.1" && version != "HTTP/1.0") ||
	   !strings.has_prefix(target, "/") {
		return ""
	}
	for ch in target {
		if ch <= ' ' || ch == '#' || ch == 0x7f {
			return ""
		}
	}
	_, query := judge.split_once(target, "?")
	return query
}

respond_ok :: proc(client: net.TCP_Socket) {
	BODY :: "<html><body><h3>LeetCode session captured — you can close this tab.</h3></body></html>"
	response := fmt.aprintf(
		"HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\nContent-Length: %d\r\n\r\n%s",
		len(BODY),
		BODY,
		allocator = context.temp_allocator,
	)
	if err := net.set_option(client, .Send_Timeout, 5 * time.Second); err != nil {
		fmt.eprintln("could not set callback response timeout:", err)
		return
	}
	// A byte-slice view is enough; sending does not modify the string.
	if _, err := net.send(client, transmute([]byte)response); err != nil {
		fmt.eprintln("could not acknowledge callback:", err)
	}
}
