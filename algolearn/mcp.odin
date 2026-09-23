package main

// Native MCP stdio frontend. It shares the learning operation registry with
// the CLI and emits newline-delimited JSON-RPC with no diagnostics on stdout.

import "core:bufio"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "core:sync"
import "core:thread"
import "learning"

MCP_PROTOCOL_VERSION :: "2025-11-25"

MCP_Server :: struct {
	workspace:    string,
	output_mutex: sync.Mutex,
	pending_mutex: sync.Mutex,
	pending:      map[string]^MCP_Call,
	threads:      [dynamic]^thread.Thread,
}

MCP_Call :: struct {
	server:       ^MCP_Server,
	id_raw:       string,
	key:          string,
	operation:    string,
	arguments:    string,
	cancelled:    bool,
}

mcp_send :: proc(server: ^MCP_Server, message: string) {
	sync.mutex_lock(&server.output_mutex)
	defer sync.mutex_unlock(&server.output_mutex)
	fmt.println(message)
}

mcp_rpc_result :: proc(server: ^MCP_Server, id_raw, result_raw: string) {
	o := learning.obj_new()
	defer learning.obj_free(&o)
	learning.obj_field_str(&o, "jsonrpc", "2.0")
	learning.obj_field_raw(&o, "id", id_raw)
	learning.obj_field_raw(&o, "result", result_raw)
	mcp_send(server, learning.obj_done(&o))
}

mcp_rpc_error :: proc(server: ^MCP_Server, id_raw: string, code: int, message: string, data_raw := "") {
	err := learning.obj_new()
	defer learning.obj_free(&err)
	learning.obj_field_int(&err, "code", code)
	learning.obj_field_str(&err, "message", message)
	if data_raw != "" { learning.obj_field_raw(&err, "data", data_raw) }
	o := learning.obj_new()
	defer learning.obj_free(&o)
	learning.obj_field_str(&o, "jsonrpc", "2.0")
	learning.obj_field_raw(&o, "id", id_raw)
	learning.obj_field_raw(&o, "error", learning.obj_done(&err))
	mcp_send(server, learning.obj_done(&o))
}

json_raw :: proc(value: json.Value) -> string {
	bytes, err := json.marshal(value)
	if err != nil { return "null" }
	defer delete(bytes)
	return strings.clone(string(bytes))
}

mcp_operation_fields :: proc(name: string) -> (required, optional: string) {
	switch name {
	case "workspace_init": required = "goal language timezone experience time_budget_minutes"; optional = "learner_id explanation_language teaching_preferences authorization_policy import_legacy"
	case "doctor": optional = "check_accounts"
	case "profile_update": optional = "learner_id goal language timezone experience explanation_language teaching_preferences authorization_policy time_budget_minutes"
	case "state_get": optional = "session_id detail"
	case "problem_search": optional = "provider query concept_id language offline limit cursor audience"
	case "problem_get": required = "problem_key"; optional = "audience offline refresh"
	case "plan_next": optional = "goal time_budget_minutes topic mode language offline exclude_problem_keys"
	case "session_start": required = "objective mode"; optional = "concept_ids budget_minutes problem_key review_item_id"
	case "session_resume": optional = "session_id"
	case "attempt_start": required = "session_id problem_key language"; optional = "action source_path runner_kind previous_attempt_id"
	case "evidence_record": required = "session_id evidence_type producer"; optional = "attempt_id concept_id content artifact_hash"
	case "hint_record": required = "session_id level"; optional = "attempt_id content concept_ids"
	case "case_add": required = "attempt_id input comparator provenance"; optional = "name expected oracle_verified oracle_basis"
	case "test_run": required = "attempt_id"; optional = "mode timeout_seconds source_selection"
	case "submission_prepare": required = "attempt_id"; optional = "account_alias"
	case "submission_send": required = "intent_id authorization_reference"
	case "job_check": required = "job_id"; optional = "wait_seconds"
	case "assessment_record": required = "session_id concept_id dimension score rationale rubric_version"; optional = "evidence_ids"
	case "session_checkpoint": required = "session_id activity summary next_action"; optional = "pause"
	case "session_close": required = "session_id reason"; optional = "review_outcome"
	case "review_due": optional = "date time_budget_minutes concept_id"
	case "review_update": required = "review_id action"; optional = "until"
	case "progress_get": optional = "goal topic date_scope"
	case "export_create": optional = "scope session_id include_source"
	case "import_validate": optional = "kind path mappings"
	case "import_apply": required = "kind source_hash"; optional = "path mappings"
	case "data_delete": required = "scope"; optional = "session_id export_id execute confirmation include_backups"
	}
	return
}

mcp_field_schema :: proc(name: string) -> string {
	if name == "time_budget_minutes" || name == "budget_minutes" || name == "limit" || name == "cursor" ||
	   name == "level" || name == "timeout_seconds" || name == "wait_seconds" || name == "expected_revision" {
		return `{"type":"integer"}`
	}
	if name == "offline" || name == "refresh" || name == "oracle_verified" || name == "pause" ||
	   name == "include_source" || name == "execute" || name == "include_backups" || name == "check_accounts" || name == "import_legacy" {
		return `{"type":"boolean"}`
	}
	if name == "concept_ids" || name == "evidence_ids" || name == "exclude_problem_keys" {
		return `{"type":"array","items":{"type":"string"}}`
	}
	if name == "mappings" { return `{"type":"object"}` }
	if name == "score" { return `{"oneOf":[{"type":"integer","minimum":0,"maximum":3},{"const":"unknown"}]}` }
	return `{"type":"string"}`
}

mcp_tool_schema :: proc(op: ^learning.Operation) -> string {
	required_text, optional_text := mcp_operation_fields(op.name)
	required := make([dynamic]string)
	defer delete(required)
	properties := learning.obj_new()
	defer learning.obj_free(&properties)
	if required_text != "" {
		for field in strings.split(required_text, " ") {
			append(&required, field)
			learning.obj_field_raw(&properties, field, mcp_field_schema(field))
		}
	}
	if optional_text != "" {
		for field in strings.split(optional_text, " ") { learning.obj_field_raw(&properties, field, mcp_field_schema(field)) }
	}
	if op.mutating {
		append(&required, "request_id", "expected_revision")
		learning.obj_field_raw(&properties, "request_id", mcp_field_schema("request_id"))
		learning.obj_field_raw(&properties, "expected_revision", mcp_field_schema("expected_revision"))
	}
	input := learning.obj_new()
	defer learning.obj_free(&input)
	learning.obj_field_str(&input, "type", "object")
	learning.obj_field_raw(&input, "properties", learning.obj_done(&properties))
	learning.obj_field_strs(&input, "required", required[:])
	learning.obj_field_bool(&input, "additionalProperties", false)
	output := learning.obj_new()
	defer learning.obj_free(&output)
	learning.obj_field_str(&output, "type", "object")
	learning.obj_field_strs(&output, "required", {"schema_version", "request_id", "workspace_revision", "status", "data", "warnings", "error", "next_actions"})
	tool := learning.obj_new()
	defer learning.obj_free(&tool)
	learning.obj_field_str(&tool, "name", op.name)
	learning.obj_field_str(&tool, "description", fmt.aprintf("Algorithm Learning operation %s; the engine rejects unexpected fields and invalid enums.", op.name))
	learning.obj_field_raw(&tool, "inputSchema", learning.obj_done(&input))
	learning.obj_field_raw(&tool, "outputSchema", learning.obj_done(&output))
	return learning.obj_done(&tool)
}

mcp_tools_list :: proc() -> string {
	tools := make([dynamic]string)
	defer delete(tools)
	for &op in learning.operations { append(&tools, mcp_tool_schema(&op)) }
	o := learning.obj_new()
	defer learning.obj_free(&o)
	learning.obj_field_raws(&o, "tools", tools[:])
	return learning.obj_done(&o)
}

mcp_call_worker :: proc(t: ^thread.Thread) {
	call := (^MCP_Call)(t.data)
	server := call.server
	input, req, parse_err := build_request(call.arguments)
	if parse_err != "" {
		mcp_rpc_error(server, call.id_raw, -32602, parse_err)
		return
	}
	store, load_err := learning.load_store(server.workspace)
	if load_err != .None {
		res := learning.error_result(load_err, "could not load the event log")
		envelope := make_envelope(req, 0, res)
		content := learning.obj_new()
		defer learning.obj_free(&content)
		item := learning.obj_new()
		defer learning.obj_free(&item)
		learning.obj_field_str(&item, "type", "text")
		learning.obj_field_str(&item, "text", envelope)
		learning.obj_field_raws(&content, "content", {learning.obj_done(&item)})
		learning.obj_field_raw(&content, "structuredContent", envelope)
		learning.obj_field_bool(&content, "isError", true)
		mcp_rpc_result(server, call.id_raw, learning.obj_done(&content))
		return
	}
	ctx := learning.Context{workspace = server.workspace, actor = "agent:mcp", host = "mcp"}
	res, found := learning.run_operation(call.operation, &ctx, &store, input, req)
	if !found {
		mcp_rpc_error(server, call.id_raw, -32602, "unknown tool")
		return
	}
	envelope := make_envelope(req, store.revision, res)
	sync.mutex_lock(&server.pending_mutex)
	cancelled := call.cancelled
	delete_key(&server.pending, call.key)
	sync.mutex_unlock(&server.pending_mutex)
	if cancelled { return }
	item := learning.obj_new()
	defer learning.obj_free(&item)
	learning.obj_field_str(&item, "type", "text")
	learning.obj_field_str(&item, "text", envelope)
	result := learning.obj_new()
	defer learning.obj_free(&result)
	learning.obj_field_raws(&result, "content", {learning.obj_done(&item)})
	learning.obj_field_raw(&result, "structuredContent", envelope)
	learning.obj_field_bool(&result, "isError", res.status == .Error)
	mcp_rpc_result(server, call.id_raw, learning.obj_done(&result))
}

mcp_start_call :: proc(server: ^MCP_Server, id_raw, operation, arguments: string) {
	call := new(MCP_Call)
	call.server = server
	call.id_raw = strings.clone(id_raw)
	call.key = strings.clone(id_raw)
	call.operation = strings.clone(operation)
	call.arguments = strings.clone(arguments)
	t := thread.create(mcp_call_worker)
	t.data = call
	sync.mutex_lock(&server.pending_mutex)
	server.pending[call.key] = call
	sync.mutex_unlock(&server.pending_mutex)
	thread.start(t)
	append(&server.threads, t)
}

mcp_cancel :: proc(server: ^MCP_Server, request_id: json.Value) {
	key := json_raw(request_id)
	defer delete(key)
	sync.mutex_lock(&server.pending_mutex)
	call, found := server.pending[key]
	if found && !call.cancelled { call.cancelled = true }
	sync.mutex_unlock(&server.pending_mutex)
	if found {
		mcp_rpc_error(server, call.id_raw, -32800, "request cancelled; any remote operation continues under its durable intent and will not be replayed")
	}
}

mcp_handle :: proc(server: ^MCP_Server, request: json.Value) -> (should_exit: bool) {
	method := learning.jstr(learning.jget(request, "method"))
	id_value := learning.jget(request, "id")
	id_raw := json_raw(id_value)
	defer delete(id_raw)
	params := learning.jget(request, "params")
	switch method {
	case "initialize":
		requested := learning.jstr(learning.jget(params, "protocolVersion"))
		if requested != MCP_PROTOCOL_VERSION {
			data := learning.obj_new()
			defer learning.obj_free(&data)
			learning.obj_field_strs(&data, "supported", {MCP_PROTOCOL_VERSION})
			mcp_rpc_error(server, id_raw, -32602, "unsupported MCP protocol version", learning.obj_done(&data))
			return false
		}
		info := learning.obj_new()
		defer learning.obj_free(&info)
		learning.obj_field_str(&info, "name", "algolearn")
		learning.obj_field_str(&info, "version", VERSION)
		tools_cap := learning.obj_new()
		defer learning.obj_free(&tools_cap)
		learning.obj_field_bool(&tools_cap, "listChanged", false)
		caps := learning.obj_new()
		defer learning.obj_free(&caps)
		learning.obj_field_raw(&caps, "tools", learning.obj_done(&tools_cap))
		result := learning.obj_new()
		defer learning.obj_free(&result)
		learning.obj_field_str(&result, "protocolVersion", MCP_PROTOCOL_VERSION)
		learning.obj_field_raw(&result, "capabilities", learning.obj_done(&caps))
		learning.obj_field_raw(&result, "serverInfo", learning.obj_done(&info))
		learning.obj_field_str(&result, "instructions", "Persist evidence-backed algorithm learning in the bound workspace; use job_check for pending remote work.")
		mcp_rpc_result(server, id_raw, learning.obj_done(&result))
	case "notifications/initialized", "notifications/progress":
	case "ping":
		mcp_rpc_result(server, id_raw, `{}`)
	case "tools/list":
		mcp_rpc_result(server, id_raw, mcp_tools_list())
	case "tools/call":
		name := learning.jstr(learning.jget(params, "name"))
		arguments := learning.jget(params, "arguments")
		if name == "" || arguments == nil {
			mcp_rpc_error(server, id_raw, -32602, "tool name and arguments object are required")
			return false
		}
		known := false
		for op in learning.operations { if op.name == name { known = true; break } }
		if !known {
			mcp_rpc_error(server, id_raw, -32602, "unknown tool")
			return false
		}
		arguments_raw := json_raw(arguments)
		defer delete(arguments_raw)
		mcp_start_call(server, id_raw, name, arguments_raw)
	case "notifications/cancelled":
		mcp_cancel(server, learning.jget(params, "requestId"))
	case "shutdown":
		mcp_rpc_result(server, id_raw, "null")
	case "exit":
		return true
	case:
		if id_value != nil { mcp_rpc_error(server, id_raw, -32601, "method not found") }
	}
	return false
}

run_mcp :: proc(opts: Options) -> int {
	server := MCP_Server{workspace = opts.workspace}
	server.pending = make(map[string]^MCP_Call)
	defer delete(server.pending)
	defer delete(server.threads)
	scanner: bufio.Scanner
	bufio.scanner_init(&scanner, os.to_reader(os.stdin))
	defer bufio.scanner_destroy(&scanner)
	for bufio.scanner_scan(&scanner) {
		line := strings.trim_space(bufio.scanner_text(&scanner))
		if line == "" { continue }
		request, err := json.parse(line, .JSON, parse_integers = true)
		if err != nil {
			mcp_rpc_error(&server, "null", -32700, "parse error")
			continue
		}
		if learning.jstr(learning.jget(request, "jsonrpc")) != "2.0" || learning.jstr(learning.jget(request, "method")) == "" {
			mcp_rpc_error(&server, "null", -32600, "invalid JSON-RPC request")
			continue
		}
		if mcp_handle(&server, request) { break }
	}
	// Clean shutdown waits for in-flight mutations so an accepted request is
	// not abandoned after a remote side effect.
	for t in server.threads { thread.destroy(t) }
	return 0
}
