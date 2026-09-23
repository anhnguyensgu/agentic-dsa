package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// Override only at build time for the integration service. Credentials never
// follow a runtime-supplied URL or HTTP redirect.
BASE_URL :: #config(LEETCODE_BASE_URL, "https://leetcode.com")

jget :: proc(v: json.Value, key: string) -> json.Value {
	o := v.(json.Object) or_else nil
	return o[key]
}
jstr :: proc(v: json.Value) -> string { return v.(string) or_else "" }
jint :: proc(v: json.Value) -> int {
	#partial switch n in v {
	case json.Integer: return int(n)
	case json.Float: return int(n)
	case string: return strconv.parse_int(n) or_else 0
	}
	return 0
}
jbool :: proc(v: json.Value) -> bool { return v.(bool) or_else false }
jarray :: proc(v: json.Value) -> json.Array { return v.(json.Array) or_else nil }
jobject :: proc() -> json.Object { return make(json.Object) }
jencode :: proc(v: $T) -> string {
	b, err := json.marshal(v)
	assert(err == nil)
	return string(b)
}
print_json :: proc(v: $T) { fmt.println(jencode(v)) }

request_credentials :: proc(required := false) -> (cfg: Config, err: Error) {
	path := config_path() or_return
	if _, e := os.stat(path, context.allocator); e == .Not_Exist && !required { return {}, nil }
	return load_config(path)
}

http_request :: proc(method, path: string, cfg: Config, body := "", timeout := 20) -> (value: json.Value, err: Error) {
	if !strings.has_prefix(path, "/") { return nil, .Usage }
	if cfg.leetcode_session != "" && !valid_credentials(cfg) { return nil, .No_Input }
	dir, de := os.make_directory_temp("", "leetcode-request-*", context.allocator)
	if de != nil { return nil, .File }
	defer os.remove_all(dir)
	if os.chmod(dir, os.perm(0o700)) != nil { return nil, .File }
	headers_path := join_path(dir, "headers")
	body_path := join_path(dir, "body")
	headers := fmt.aprintf("Content-Type: application/json\nReferer: %s/\nOrigin: %s\nUser-Agent: leetcode-odin/0.1\n", BASE_URL, BASE_URL)
	if cfg.leetcode_session != "" {
		headers = concat(headers, fmt.aprintf("Cookie: LEETCODE_SESSION=%s; csrftoken=%s\nx-csrftoken: %s\n", cfg.leetcode_session, cfg.csrf_token, cfg.csrf_token))
	}
	if write_private_file(headers_path, transmute([]byte)headers) != nil { return nil, .File }
	cmd := make([dynamic]string)
	append(&cmd, "curl", "-q", "-sS", "--connect-timeout", "10", "--max-time", fmt.aprintf("%d", timeout),
		"--request", method, "--url", concat(BASE_URL, path), "--header", concat("@", headers_path), "--write-out", "\n%{http_code}")
	if body != "" {
		if write_private_file(body_path, transmute([]byte)body) != nil { return nil, .File }
		append(&cmd, "--data-binary", concat("@", body_path))
	}
	state, output, stderr, pe := os.process_exec({command = cmd[:]}, context.allocator)
	if pe != nil || state.exit_code != 0 {
		// curl's error text never needs request headers or response bodies.
		fmt.eprintf("curl request failed (exit %d): %s\n", state.exit_code, string(stderr))
		return nil, .Network
	}
	text := string(output)
	i := strings.last_index(text, "\n")
	if i < 0 { return nil, .Network }
	status := strconv.parse_int(text[i+1:]) or_else 0
	if status != 200 {
		switch status {
		case 401: fmt.eprintln("authentication expired; log in again"); return nil, .Not_Signed_In
		case 403: fmt.eprintln("HTTP 403: session/CSRF rejected or Cloudflare challenge; log in in your browser")
		case 429: fmt.eprintln("HTTP 429: LeetCode rate limit; try again later")
		case 404: return nil, .Not_Found
		case: fmt.eprintf("LeetCode returned HTTP %d\n", status)
		}
		return nil, .API
	}
	v, je := json.parse(text[:i], .JSON, parse_integers = true)
	if je != nil { fmt.eprintln("expected JSON; received an invalid response or browser challenge"); return nil, .API }
	return v, nil
}

graphql :: proc(query: string, variables: json.Object, cfg: Config) -> (data: json.Value, err: Error) {
	response := http_request("POST", "/graphql/", cfg, jencode(struct {query: string, variables: json.Object}{query, variables})) or_return
	if len(jarray(jget(response, "errors"))) > 0 { fmt.eprintln("LeetCode returned GraphQL errors"); return nil, .API }
	data = jget(response, "data")
	if _, ok := data.(json.Object); !ok { return nil, .API }
	return data, nil
}

join_path :: proc(a, b: string) -> string {
	return os.join_path({a, b}, context.allocator) or_else ""
}

concat :: proc(parts: ..string) -> string { return strings.concatenate(parts) or_else "" }

write_file :: proc(path, data: string) -> Error {
	if e := os.write_entire_file(path, data, os.perm(0o600)); e != nil {
		fmt.eprintf("%s: %s\n", path, os.error_string(e)); return .File
	}
	return nil
}
