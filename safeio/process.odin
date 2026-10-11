package safeio

import "core:os"
import "core:strings"
import "core:time"

DEFAULT_OUTPUT_LIMIT :: 256 * 1024

Process_Result :: struct {
	exit_code:       int,
	stdout:          string,
	stderr:          string,
	timed_out:       bool,
	output_exceeded: bool,
	start_failed:    bool,
}

// ok reports a clean, complete, zero-exit run.
ok :: proc(r: Process_Result) -> bool {
	return !r.start_failed && !r.timed_out && !r.output_exceeded && r.exit_code == 0
}

// run executes command (an argument vector; no shell) with stdin supplied as
// data, a wall-clock timeout, and a combined stdout+stderr size limit. The
// child is killed when either bound is exceeded. Captured output is truncated
// to output_limit bytes and allocated with context.allocator.
//
// Unless keep_credentials is set, the child gets a scrubbed environment: learner
// code and compilers never see provider sessions, tokens, or cookies.
run :: proc(
	command: []string,
	stdin := "",
	timeout := 10 * time.Second,
	output_limit := DEFAULT_OUTPUT_LIMIT,
	keep_credentials := false,
) -> (result: Process_Result) {
	tmp, tmp_err := os.make_directory_temp("", "safeio-run-*", context.allocator)
	if tmp_err != nil {
		result.start_failed = true
		return
	}
	defer os.remove_all(tmp)

	in_path := join_path(tmp, "stdin")
	out_path := join_path(tmp, "stdout")
	err_path := join_path(tmp, "stderr")
	if write_private_file(in_path, transmute([]byte)stdin) != nil {
		result.start_failed = true
		return
	}
	in_file, in_err := os.open(in_path)
	out_file, out_err := os.create(out_path)
	err_file, err_err := os.create(err_path)
	defer {
		if in_file != nil { os.close(in_file) }
		if out_file != nil { os.close(out_file) }
		if err_file != nil { os.close(err_file) }
	}
	if in_err != nil || out_err != nil || err_err != nil {
		result.start_failed = true
		return
	}

	env: []string
	if keep_credentials {
		env, _ = os.environ(context.allocator)
	} else {
		env = scrubbed_environment()
	}
	process, start_err := os.process_start({
		command = command,
		env     = env,
		stdin   = in_file,
		stdout  = out_file,
		stderr  = err_file,
	})
	if start_err != nil {
		result.start_failed = true
		return
	}

	started := time.tick_now()
	for {
		state, wait_err := os.process_wait(process, 20 * time.Millisecond)
		if wait_err == nil {
			result.exit_code = state.exit_code
			break
		}
		stop := false
		switch {
		case wait_err != .Timeout:
			result.start_failed = true
			stop = true
		case output_size(out_path) + output_size(err_path) > i64(output_limit):
			result.output_exceeded = true
			stop = true
		case time.tick_since(started) >= timeout:
			result.timed_out = true
			stop = true
		}
		if stop {
			_ = os.process_kill(process)
			_, _ = os.process_wait(process)
			break
		}
	}

	result.stdout = read_bounded(out_path, output_limit)
	result.stderr = read_bounded(err_path, output_limit)
	return
}

// scrubbed_environment returns the current environment without entries that
// look like credentials or belong to a provider CLI.
scrubbed_environment :: proc(allocator := context.allocator) -> []string {
	env, err := os.environ(allocator)
	if err != nil {
		return nil
	}
	kept := 0
	for item in env {
		if !is_credential(item) {
			env[kept] = item
			kept += 1
		}
	}
	return env[:kept]
}

@(private)
is_credential :: proc(item: string) -> bool {
	MARKERS :: [?]string{"token=", "secret=", "password=", "cookie=", "session=", "authorization="}
	PREFIXES :: [?]string{"leetcode_", "kattis_"}

	lower := strings.to_lower(item, context.temp_allocator)
	for marker in MARKERS {
		if strings.contains(lower, marker) { return true }
	}
	for prefix in PREFIXES {
		if strings.has_prefix(lower, prefix) { return true }
	}
	return false
}

@(private)
output_size :: proc(path: string) -> i64 {
	info, err := os.stat(path, context.temp_allocator)
	return info.size if err == nil else 0
}

@(private)
read_bounded :: proc(path: string, limit: int) -> string {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		return ""
	}
	return string(data[:min(len(data), limit)])
}

@(private)
join_path :: proc(a, b: string) -> string {
	return os.join_path({a, b}, context.allocator) or_else ""
}
