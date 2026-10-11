package main

import "core:net"
import "core:testing"
import "core:time"

@(test)
app_errors_are_not_success :: proc(t: ^testing.T) {
	for kind in Error {
		if kind == .None {
			continue
		}
		err: Error = kind
		testing.expectf(t, err != nil, "%v must not compare equal to nil", kind)
	}

	fail :: proc() -> Error {
		return .No_Input
	}
	propagate :: proc() -> (value: int, err: Error) {
		fail() or_return
		return 42, nil
	}
	value, err := propagate()
	testing.expect(t, err != nil)
	testing.expect_value(t, value, 0)
}

@(test)
callback_rejects_malformed_requests :: proc(t: ^testing.T) {
	requests := []string{
		"",
		"GET /?session=secret HTTP/1.1",
		"GET /?session=secret HTTP/1.1\r\n",
		"GET /?session=secret\r\n\r\n",
		"GET /?session=secret NOT-HTTP\r\n\r\n",
		"POST /?session=secret HTTP/1.1\r\n\r\n",
		"GET http://example.com/?session=secret HTTP/1.1\r\n\r\n",
	}
	for request in requests {
		testing.expectf(t, extract_query(request) == "", "accepted malformed request: %q", request)
	}
}

@(test)
callback_accepts_complete_get_requests :: proc(t: ^testing.T) {
	testing.expect_value(t, extract_query("GET /?session=s HTTP/1.1\r\nHost: localhost\r\n\r\n"), "session=s")
	testing.expect_value(t, extract_query("GET /callback?cookie=a%3Db HTTP/1.0\r\n\r\n"), "cookie=a%3Db")
}

// Each test gets an ephemeral loopback port; no browser or remote service.
test_tcp_pair :: proc(t: ^testing.T) -> (server, client: net.TCP_Socket, ok: bool) {
	listener, listen_err := net.listen_tcp({address = net.IP4_Loopback, port = 0})
	if !testing.expect(t, listen_err == nil) {
		return
	}
	defer net.close(listener)
	endpoint, endpoint_err := net.bound_endpoint(listener)
	if !testing.expect(t, endpoint_err == nil) {
		return
	}
	connected, dial_err := net.dial_tcp(endpoint)
	if !testing.expect(t, dial_err == nil) {
		return
	}
	defer if !ok {
		net.close(connected)
	}
	accepted, accept_err := accept_callback(listener, time.Second)
	if !testing.expect(t, accept_err == nil) {
		return
	}
	return accepted, connected, true
}

@(test)
callback_read_requires_complete_headers :: proc(t: ^testing.T) {
	cases := []struct {request: string, capacity: int, expected: Error}{
		{"GET /?session=s HTTP/1.1\r\n\r\n", 64, .None},
		{"GET /?session=s HTTP/1.1\r\n", 64, .Callback_Failed},
		{"GET /?session=s HTTP/1.1\r\n\r\n", 16, .Callback_Failed},
		{"", 64, .Callback_Failed},
	}
	for c in cases {
		server, client, ok := test_tcp_pair(t)
		if !ok {
			return
		}
		defer net.close(server)
		defer net.close(client)
		_, send_err := net.send(client, transmute([]byte)c.request)
		testing.expect(t, send_err == nil)
		testing.expect(t, net.shutdown(client, .Send) == nil)
		buffer: [64]byte
		req, err := read_http_request(server, buffer[:c.capacity], time.Second)
		testing.expect_value(t, err, c.expected)
		if err == nil {
			testing.expect_value(t, req, c.request)
			testing.expect(t, raw_data(req) == raw_data(buffer[:]))
		} else {
			testing.expect_value(t, req, "")
		}
	}
}

@(test)
callback_accept_and_receive_time_out :: proc(t: ^testing.T) {
	listener, listen_err := net.listen_tcp({address = net.IP4_Loopback, port = 0})
	if !testing.expect(t, listen_err == nil) {
		return
	}
	defer net.close(listener)
	started := time.tick_now()
	_, accept_err := accept_callback(listener, 15 * time.Millisecond)
	testing.expect_value(t, accept_err, Error.Callback_Failed)
	testing.expect(t, time.tick_since(started) < time.Second)

	server, client, ok := test_tcp_pair(t)
	if !ok {
		return
	}
	defer net.close(server)
	defer net.close(client)
	buffer: [64]byte
	started = time.tick_now()
	_, read_err := read_http_request(server, buffer[:], 15 * time.Millisecond)
	testing.expect_value(t, read_err, Error.Callback_Failed)
	testing.expect(t, time.tick_since(started) < time.Second)
}

@(test)
command_usage_returns_failure :: proc(t: ^testing.T) {
	testing.expect_value(t, run(nil), 2)
	testing.expect_value(t, run({"not-a-command"}), 2)
}
