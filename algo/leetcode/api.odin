package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "../safeio"

// Override only at build time for the integration service. Credentials never
// follow a runtime-supplied URL or HTTP redirect.
BASE_URL :: #config(LEETCODE_BASE_URL, "https://leetcode.com")

// LeetCode responses are proxied and reshaped freely, so they stay dynamic
// json.Values. These accessors return zero values for missing or mistyped
// fields; callers validate the fields they depend on.

jget :: proc(v: json.Value, key: string) -> json.Value {
	o := v.(json.Object) or_else nil
	return o[key]
}

jstr :: proc(v: json.Value) -> string {
	return v.(string) or_else ""
}

jint :: proc(v: json.Value) -> int {
	#partial switch n in v {
	case json.Integer: return int(n)
	case json.Float:   return int(n)
	case string:       return strconv.parse_int(n) or_else 0
	}
	return 0
}

jbool :: proc(v: json.Value) -> bool {
	return v.(bool) or_else false
}

jarray :: proc(v: json.Value) -> json.Array {
	return v.(json.Array) or_else nil
}

jobject :: proc() -> json.Object {
	return make(json.Object)
}

jencode :: proc(v: any) -> string {
	data, err := json.marshal(v)
	assert(err == nil, "values built by this program must be marshalable")
	return string(data)
}

print_json :: proc(v: any) {
	fmt.println(jencode(v))
}

// request_credentials loads saved credentials; when they are optional and
// absent, requests go out anonymously.
request_credentials :: proc(required := false) -> (cfg: Config, err: Error) {
	path := config_path() or_return
	if _, stat_err := os.stat(path, context.allocator); stat_err == .Not_Exist && !required {
		return {}, nil
	}
	return load_config(path)
}

// http_request sends one request through curl. Headers and bodies travel in
// private temporary files, so credentials and code never appear in argv.
http_request :: proc(method, path: string, cfg: Config, body := "", timeout := 20) -> (value: json.Value, err: Error) {
	if !strings.has_prefix(path, "/") {
		return nil, .Usage
	}
	if cfg.leetcode_session != "" && !valid_credentials(cfg) {
		return nil, .No_Input
	}
	dir, dir_err := os.make_directory_temp("", "leetcode-request-*", context.allocator)
	if dir_err != nil {
		return nil, .File
	}
	defer os.remove_all(dir)
	if os.chmod(dir, os.perm(0o700)) != nil {
		return nil, .File
	}

	headers := strings.builder_make()
	fmt.sbprintf(&headers, "Content-Type: application/json\nReferer: %s/\nOrigin: %s\nUser-Agent: leetcode-odin/0.2\n", BASE_URL, BASE_URL)
	if cfg.leetcode_session != "" {
		fmt.sbprintf(&headers, "Cookie: LEETCODE_SESSION=%s; csrftoken=%s\nx-csrftoken: %s\n", cfg.leetcode_session, cfg.csrf_token, cfg.csrf_token)
	}
	headers_path := join_path(dir, "headers")
	if write_private_file(headers_path, strings.to_string(headers)) != nil {
		return nil, .File
	}

	command := make([dynamic]string)
	append(
		&command,
		"curl", "-q", "-sS",
		"--connect-timeout", "10",
		"--max-time", fmt.tprint(timeout),
		"--request", method,
		"--url", concat(BASE_URL, path),
		"--header", concat("@", headers_path),
		"--write-out", "\n%{http_code}",
	)
	if body != "" {
		body_path := join_path(dir, "body")
		if write_private_file(body_path, body) != nil {
			return nil, .File
		}
		append(&command, "--data-binary", concat("@", body_path))
	}
	state, output, stderr, exec_err := os.process_exec({command = command[:]}, context.allocator)
	if exec_err != nil || state.exit_code != 0 {
		// curl's error text never contains request headers or response bodies.
		fmt.eprintf("curl request failed (exit %d): %s\n", state.exit_code, string(stderr))
		return nil, .Network
	}

	text := string(output)
	newline := strings.last_index(text, "\n")
	if newline < 0 {
		return nil, .Network
	}
	switch status := strconv.parse_int(text[newline + 1:]) or_else 0; status {
	case 200:
	case 401:
		fmt.eprintln("authentication expired; log in again")
		return nil, .Not_Signed_In
	case 403:
		fmt.eprintln("HTTP 403: session/CSRF rejected or Cloudflare challenge; log in in your browser")
		return nil, .API
	case 404:
		return nil, .Not_Found
	case 429:
		fmt.eprintln("HTTP 429: LeetCode rate limit; try again later")
		return nil, .API
	case:
		fmt.eprintf("LeetCode returned HTTP %d\n", status)
		return nil, .API
	}
	parsed, parse_err := json.parse(text[:newline], .JSON, parse_integers = true)
	if parse_err != nil {
		fmt.eprintln("expected JSON; received an invalid response or browser challenge")
		return nil, .API
	}
	return parsed, nil
}

Graphql_Request :: struct {
	query:     string,
	variables: json.Object,
}

graphql :: proc(query: string, variables: json.Object, cfg: Config) -> (data: json.Value, err: Error) {
	response := http_request("POST", "/graphql/", cfg, jencode(Graphql_Request{query, variables})) or_return
	if len(jarray(jget(response, "errors"))) > 0 {
		fmt.eprintln("LeetCode returned GraphQL errors")
		return nil, .API
	}
	data = jget(response, "data")
	if _, ok := data.(json.Object); !ok {
		return nil, .API
	}
	return data, nil
}

join_path :: proc(a, b: string) -> string {
	return os.join_path({a, b}, context.allocator) or_else ""
}

concat :: proc(parts: ..string) -> string {
	return strings.concatenate(parts) or_else ""
}

write_file :: proc(path, data: string) -> Error {
	if err := os.write_entire_file(path, data, os.perm(0o600)); err != nil {
		fmt.eprintf("%s: %s\n", path, os.error_string(err))
		return .File
	}
	return nil
}

write_private_file :: proc(path, data: string) -> os.Error {
	return safeio.write_private_file(path, transmute([]byte)data)
}
