package learning

// Provider discovery is conservative: implemented adapter capability is
// separate from current availability. Ordinary doctor checks versions and
// paths only; it never initiates login or uploads source.

import "core:encoding/json"
import "core:os"
import "core:strings"

find_executable :: proc(workspace, name: string) -> string {
	local_candidates := [?]string{
		join({workspace, "bin", name}),
		join({workspace, name}),
	}
	for candidate in local_candidates { if os.is_file(candidate) { return candidate } }
	path_env := os.get_env("PATH", context.allocator)
	for dir in strings.split(path_env, ":") {
		candidate := join({dir, name})
		if os.is_file(candidate) { return candidate }
	}
	return ""
}

binary_version :: proc(path: string) -> string {
	if path == "" { return "" }
	obs := run_bounded({path, "--version"}, "", 3, 16 * 1024)
	if obs.start_failed || obs.timed_out || obs.exit_code != 0 { return "" }
	return strings.trim_space(obs.stdout)
}

provider_capability_json :: proc(name, path, version: string) -> string {
	o := obj_new()
	defer obj_free(&o)
	obj_field_str(&o, "provider", name)
	obj_field_bool(&o, "implemented", true)
	obj_field_bool(&o, "available", path != "" && version != "")
	obj_field_str(&o, "executable", path)
	obj_field_str(&o, "version", version)
	if path == "" { obj_field_str(&o, "reason", "compatible provider binary not found") }
	else if version == "" { obj_field_str(&o, "reason", "provider binary does not expose the required version contract") }
	else { obj_field_str(&o, "reason", "") }
	local_languages := [?]string{"odin"}
	obj_field_strs(&o, "local_languages", local_languages[:])
	if name == "leetcode" {
		obj_field_bool(&o, "remote_odin", false)
		obj_field_str(&o, "remote_odin_reason", "LeetCode does not offer Odin on its remote judge")
	} else {
		obj_field_bool(&o, "remote_odin", path != "" && version != "")
		obj_field_str(&o, "remote_odin_reason", "availability still requires an authenticated Kattis account and current judge language support")
	}
	return obj_done(&o)
}

op_doctor :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {}, {"check_accounts"}); fail.status == .Error { return fail }
	res := ok_result()
	odin_path := find_executable(ctx.workspace, "odin")
	leetcode_path := find_executable(ctx.workspace, "leetcode")
	if leetcode_path == "" { leetcode_path = find_executable(ctx.workspace, "bin/leetcode") }
	kattis_path := find_executable(ctx.workspace, "kattis")
	if kattis_path == "" { kattis_path = find_executable(ctx.workspace, "kattis.bin") }
	leetcode_version := binary_version(leetcode_path)
	kattis_version := binary_version(kattis_path)
	providers := make([dynamic]string)
	defer delete(providers)
	append(&providers, provider_capability_json("leetcode", leetcode_path, leetcode_version))
	append(&providers, provider_capability_json("kattis", kattis_path, kattis_version))
	obj_field_str(&res.data, "engine_version", ENGINE_VERSION)
	obj_field_int(&res.data, "schema_version", SCHEMA_VERSION)
	obj_field_str(&res.data, "catalog_version", CATALOG_VERSION)
	problems, catalog_err := catalog_problems()
	obj_field_bool(&res.data, "catalog_available", catalog_err == .None && len(problems) >= 36)
	obj_field_int(&res.data, "catalog_problem_count", len(problems))
	obj_field_bool(&res.data, "workspace_accessible", os.is_directory(ctx.workspace))
	obj_field_bool(&res.data, "workspace_initialized", os.is_file(manifest_path(ctx.workspace)))
	obj_field_bool(&res.data, "event_log_readable", store.tail_warning == "")
	obj_field_bool(&res.data, "odin_compiler_available", odin_path != "")
	obj_field_raws(&res.data, "providers", providers[:])
	ready := os.is_directory(ctx.workspace) && odin_path != "" && catalog_err == .None
	obj_field_bool(&res.data, "ready_for_local_practice", ready)
	if !ready { append(&res.next_actions, "fix the reported workspace, compiler, or catalogue problem before local practice") }
	if jbool(jget(input, "check_accounts")) {
		append(&res.warnings, "account verification is not performed by the deterministic engine; use each provider's explicit status command")
		append(&res.next_actions, "run the provider status command only when account verification is wanted")
	}
	return res
}
