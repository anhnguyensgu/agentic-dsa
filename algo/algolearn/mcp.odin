package main

// Native MCP stdio server. It shares the operation registry with the CLI and
// writes newline-delimited JSON-RPC to stdout; diagnostics go to stderr only.
//
// Each tools/call runs on its own thread inside its own arena, so a slow test
// run never blocks pings, listing, or cancellation. Server-lifetime data lives
// on the heap; everything a single message needs lives in a per-message arena.

import "base:runtime"
import "core:bufio"
import "core:encoding/json"
import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:reflect"
import "core:strings"
import "core:sync"
import "core:thread"
import "learning"

MCP_PROTOCOL_VERSION :: "2025-11-25"

// JSON-RPC error codes.
PARSE_ERROR :: -32700
INVALID_REQUEST :: -32600
METHOD_NOT_FOUND :: -32601
INVALID_PARAMS :: -32602
REQUEST_CANCELLED :: -32800

Raw_JSON :: learning.Raw_JSON

MCP_Server :: struct {
	workspace:     string,
	output_mutex:  sync.Mutex,
	pending_mutex: sync.Mutex,
	pending:       map[Raw_JSON]^MCP_Call, // in-flight calls by request id
	threads:       [dynamic]^thread.Thread,
}

// MCP_Call is heap-owned; its worker frees it once it leaves the pending map.
MCP_Call :: struct {
	server:    ^MCP_Server,
	id:        Raw_JSON,
	operation: string,
	arguments: string,
	cancelled: bool,
}

Rpc_Request :: struct {
	jsonrpc: string,
	id:      Raw_JSON, // absent for notifications
	method:  string,
	params:  Raw_JSON,
}

Rpc_Result :: struct {
	jsonrpc: string,
	id:      Raw_JSON,
	result:  Raw_JSON,
}

Rpc_Error :: struct {
	jsonrpc: string,
	id:      Raw_JSON,
	error:   struct {
		code:    int,
		message: string,
		data:    Maybe(Raw_JSON) `json:",omitempty"`,
	},
}

serve_mcp :: proc(workspace: string) -> int {
	heap := runtime.heap_allocator()
	server := MCP_Server{
		workspace = strings.clone(workspace, heap),
		pending   = make(map[Raw_JSON]^MCP_Call, heap),
		threads   = make([dynamic]^thread.Thread, heap),
	}

	message_arena: virtual.Arena
	if virtual.arena_init_growing(&message_arena) != nil {
		fmt.eprintln("algolearn: out of memory")
		return 1
	}
	defer virtual.arena_destroy(&message_arena)

	scanner: bufio.Scanner
	bufio.scanner_init(&scanner, os.to_reader(os.stdin), heap)
	defer bufio.scanner_destroy(&scanner)
	for bufio.scanner_scan(&scanner) {
		virtual.arena_free_all(&message_arena)
		context.allocator = virtual.arena_allocator(&message_arena)
		if handle_message(&server, bufio.scanner_text(&scanner)) {
			break
		}
	}

	// Clean shutdown waits for in-flight calls, so an accepted mutation is
	// never abandoned after a remote side effect.
	for t in server.threads {
		thread.destroy(t)
	}
	return 0
}

// handle_message processes one JSON-RPC line and reports whether to exit.
handle_message :: proc(server: ^MCP_Server, raw_line: string) -> (exit: bool) {
	line := strings.trim_space(raw_line)
	if line == "" {
		return false
	}
	if !json.is_valid(transmute([]byte)line, .JSON) {
		send_error(server, "null", PARSE_ERROR, "parse error")
		return false
	}
	request: Rpc_Request
	if !learning.decode(line, &request) || request.jsonrpc != "2.0" || request.method == "" {
		send_error(server, "null", INVALID_REQUEST, "invalid JSON-RPC request")
		return false
	}

	switch request.method {
	case "initialize":
		initialize(server, request)
	case "notifications/initialized", "notifications/progress":
	case "ping":
		send_result(server, request.id, "{}")
	case "tools/list":
		send_result(server, request.id, tools_list())
	case "tools/call":
		start_call(server, request)
	case "notifications/cancelled":
		Cancel :: struct {
			requestId: Raw_JSON,
		}
		params: Cancel
		learning.decode(string(request.params), &params)
		cancel_call(server, params.requestId)
	case "shutdown":
		send_result(server, request.id, "null")
	case "exit":
		return true
	case:
		if request.id != "" {
			send_error(server, request.id, METHOD_NOT_FOUND, "method not found")
		}
	}
	return false
}

initialize :: proc(server: ^MCP_Server, request: Rpc_Request) {
	Params :: struct {
		protocolVersion: string,
	}
	params: Params
	learning.decode(string(request.params), &params)
	if params.protocolVersion != MCP_PROTOCOL_VERSION {
		Supported :: struct {
			supported: []string,
		}
		versions := [?]string{MCP_PROTOCOL_VERSION}
		send_error(server, request.id, INVALID_PARAMS, "unsupported MCP protocol version", learning.to_json(Supported{versions[:]}))
		return
	}

	Result :: struct {
		protocolVersion: string,
		capabilities:    struct {
			tools: struct {
				listChanged: bool,
			},
		},
		serverInfo:      struct {
			name:    string,
			version: string,
		},
		instructions:    string,
	}
	result: Result
	result.protocolVersion = MCP_PROTOCOL_VERSION
	result.serverInfo = {"algolearn", VERSION}
	result.instructions = "Persist evidence-backed algorithm learning in the bound workspace; use job_check for pending remote work."
	send_result(server, request.id, learning.to_json(result))
}

// -- tools ---------------------------------------------------------------------

Tool :: struct {
	name:         string,
	description:  string,
	inputSchema:  struct {
		type:                 string,
		properties:           map[string]Raw_JSON,
		required:             []string,
		additionalProperties: bool,
	},
	outputSchema: struct {
		type:     string,
		required: []string,
	},
}

ENVELOPE_FIELDS := []string{"schema_version", "request_id", "workspace_revision", "status", "data", "warnings", "error", "next_actions"}

// tools_list derives each tool's input schema from its operation's params
// struct, so the schema and the engine's validation cannot drift apart.
tools_list :: proc() -> Raw_JSON {
	tools := make([]Tool, len(learning.OPERATIONS))
	for op, i in learning.OPERATIONS {
		t := &tools[i]
		t.name = op.name
		t.description = fmt.aprintf("Algorithm Learning operation %s; the engine rejects unexpected fields and invalid enums.", op.name)
		t.inputSchema.type = "object"
		t.inputSchema.properties = make(map[string]Raw_JSON)
		for field in reflect.struct_fields_zipped(op.params) {
			t.inputSchema.properties[field.name] = field_schema(field.name, field.type.id)
		}
		required := make([dynamic]string)
		append(&required, ..op.required)
		if op.mutating {
			t.inputSchema.properties["request_id"] = field_schema("request_id", string)
			t.inputSchema.properties["expected_revision"] = field_schema("expected_revision", int)
			append(&required, "request_id", "expected_revision")
		}
		t.inputSchema.required = required[:]
		t.outputSchema = {"object", ENVELOPE_FIELDS}
	}

	Tools :: struct {
		tools: []Tool,
	}
	// Sorted keys keep the property maps byte-stable.
	data, err := json.marshal(Tools{tools}, {sort_maps_by_key = true})
	assert(err == nil)
	return Raw_JSON(data)
}

field_schema :: proc(name: string, type: typeid) -> Raw_JSON {
	switch type {
	case string, Maybe(string):
		return `{"type":"string"}`
	case int, Maybe(int):
		return `{"type":"integer"}`
	case bool:
		return `{"type":"boolean"}`
	case []string:
		return `{"type":"array","items":{"type":"string"}}`
	case Raw_JSON:
		return `{"type":"object"}`
	case json.Value:
		if name == "score" {
			return `{"oneOf":[{"type":"integer","minimum":0,"maximum":3},{"const":"unknown"}]}`
		}
	}
	return "{}"
}

// -- calls ---------------------------------------------------------------------

start_call :: proc(server: ^MCP_Server, request: Rpc_Request) {
	Params :: struct {
		name:      string,
		arguments: Raw_JSON,
	}
	params: Params
	learning.decode(string(request.params), &params)
	if params.name == "" || params.arguments == "" {
		send_error(server, request.id, INVALID_PARAMS, "tool name and arguments object are required")
		return
	}
	if _, known := learning.find_operation(params.name); !known {
		send_error(server, request.id, INVALID_PARAMS, "unknown tool")
		return
	}

	// The call and its thread outlive this message, so they live on the heap.
	context.allocator = runtime.heap_allocator()
	call := new(MCP_Call)
	call^ = {
		server    = server,
		id        = Raw_JSON(strings.clone(string(request.id))),
		operation = strings.clone(params.name),
		arguments = strings.clone(string(params.arguments)),
	}
	t := thread.create(call_worker)
	t.data = call
	sync.guard(&server.pending_mutex)
	server.pending[call.id] = call
	append(&server.threads, t)
	thread.start(t)
}

call_worker :: proc(t: ^thread.Thread) {
	call := (^MCP_Call)(t.data)
	server := call.server
	defer free_call(call)

	// Without an arena the call still runs, on the heap, so it is answered.
	arena: virtual.Arena
	allocator := runtime.heap_allocator()
	if virtual.arena_init_growing(&arena) == nil {
		allocator = virtual.arena_allocator(&arena)
	}
	defer virtual.arena_destroy(&arena)
	context.allocator = allocator
	defer free_all(context.temp_allocator)

	input, req, message := learning.new_request(call.arguments)
	if message != "" {
		finish_call(call, error_message(call.id, INVALID_PARAMS, message))
		return
	}
	res: learning.Result
	revision := 0
	if store, load_err := learning.load_store(server.workspace); load_err != nil {
		res = learning.failure_result({code = load_err, message = "could not load the event log"})
	} else {
		ctx := learning.Context{workspace = server.workspace, actor = "agent:mcp", host = "mcp"}
		res, _ = learning.run_operation(call.operation, &ctx, &store, input, req)
		revision = store.revision
	}

	envelope := learning.envelope(req, revision, res)
	Content :: struct {
		type: string,
		text: string,
	}
	Call_Result :: struct {
		content:           []Content,
		structuredContent: Raw_JSON,
		isError:           bool,
	}
	content := [?]Content{{"text", string(envelope)}}
	result := Call_Result{content[:], envelope, res.status == .Error}
	finish_call(call, learning.to_json(Rpc_Result{"2.0", call.id, learning.to_json(result)}))
}

// finish_call leaves the pending map and sends the response unless the
// client cancelled the call while it ran.
finish_call :: proc(call: ^MCP_Call, response: Raw_JSON) {
	server := call.server
	sync.lock(&server.pending_mutex)
	cancelled := call.cancelled
	delete_key(&server.pending, call.id)
	sync.unlock(&server.pending_mutex)
	if !cancelled {
		send(server, response)
	}
}

free_call :: proc(call: ^MCP_Call) {
	context.allocator = runtime.heap_allocator()
	delete(string(call.id))
	delete(call.operation)
	delete(call.arguments)
	free(call)
}

// A cancelled call still runs to completion under its durable intent; only
// its response is replaced by the cancellation error.
cancel_call :: proc(server: ^MCP_Server, request_id: Raw_JSON) {
	sync.lock(&server.pending_mutex)
	call, found := server.pending[request_id]
	if found {
		call.cancelled = true
	}
	sync.unlock(&server.pending_mutex)
	if found {
		send_error(server, request_id, REQUEST_CANCELLED, "request cancelled; any remote operation continues under its durable intent and will not be replayed")
	}
}

// -- output --------------------------------------------------------------------

send :: proc(server: ^MCP_Server, message: Raw_JSON) {
	sync.guard(&server.output_mutex)
	fmt.println(message)
}

send_result :: proc(server: ^MCP_Server, id: Raw_JSON, result: Raw_JSON) {
	send(server, learning.to_json(Rpc_Result{"2.0", id, result}))
}

send_error :: proc(server: ^MCP_Server, id: Raw_JSON, code: int, message: string, data: Maybe(Raw_JSON) = nil) {
	send(server, error_message(id, code, message, data))
}

error_message :: proc(id: Raw_JSON, code: int, message: string, data: Maybe(Raw_JSON) = nil) -> Raw_JSON {
	response := Rpc_Error{jsonrpc = "2.0", id = id}
	response.error = {code, message, data}
	return learning.to_json(response)
}
