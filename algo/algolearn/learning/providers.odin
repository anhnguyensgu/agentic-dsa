package learning

// Provider discovery is conservative: an implemented adapter is separate from
// one that is available now. The doctor checks versions and paths only; it
// never starts a login or uploads source.

import "core:os"
import "core:strings"
import "core:time"
import "../../safeio"

PROVIDERS :: [?]string{"leetcode", "kattis"}

// Languages every provider supports through the local runner.
LOCAL_LANGUAGES := []string{"odin"}

// find_executable looks in the workspace (bin/ first), then on PATH.
find_executable :: proc(workspace, name: string) -> string {
	for candidate in ([?]string{join(workspace, "bin", name), join(workspace, name)}) {
		if os.is_file(candidate) {
			return candidate
		}
	}
	for dir in strings.split(os.get_env("PATH", context.allocator), ":") {
		if candidate := join(dir, name); os.is_file(candidate) {
			return candidate
		}
	}
	return ""
}

binary_version :: proc(path: string) -> string {
	if path == "" {
		return ""
	}
	run := safeio.run({path, "--version"}, timeout = 3 * time.Second, output_limit = 16 * 1024)
	return strings.trim_space(run.stdout) if safeio.ok(run) else ""
}

Provider_Status :: struct {
	provider:           string,
	implemented:        bool,
	available:          bool,
	executable:         string,
	version:            string,
	reason:             string,
	local_languages:    []string,
	remote_odin:        bool,
	remote_odin_reason: string,
}

provider_status :: proc(provider, path, version: string) -> (s: Provider_Status) {
	s = {
		provider        = provider,
		implemented     = true,
		available       = path != "" && version != "",
		executable      = path,
		version         = version,
		local_languages = LOCAL_LANGUAGES,
	}
	switch {
	case path == "":
		s.reason = "compatible provider binary not found"
	case version == "":
		s.reason = "provider binary does not expose the required version contract"
	}
	if provider == "leetcode" {
		s.remote_odin_reason = "LeetCode does not offer Odin on its remote judge"
	} else {
		s.remote_odin = s.available
		s.remote_odin_reason = "availability still requires an authenticated Kattis account and current judge language support"
	}
	return
}

Doctor_Params :: struct {
	check_accounts: bool,
}

op_doctor :: proc(ctx: ^Context, store: ^Store, input: Input, req: Request) -> (res: Result, err: Op_Error) {
	p := params(input, Doctor_Params) or_return
	providers := make([]Provider_Status, len(PROVIDERS))
	for name, i in PROVIDERS {
		path := find_executable(ctx.workspace, name)
		providers[i] = provider_status(name, path, binary_version(path))
	}
	problems, catalog_err := catalog_problems()
	workspace_accessible := os.is_directory(ctx.workspace)
	odin_available := find_executable(ctx.workspace, "odin") != ""
	ready := workspace_accessible && odin_available && catalog_err == nil

	Data :: struct {
		engine_version:           string,
		schema_version:           int,
		catalog_version:          string,
		catalog_available:        bool,
		catalog_problem_count:    int,
		workspace_accessible:     bool,
		workspace_initialized:    bool,
		event_log_readable:       bool,
		odin_compiler_available:  bool,
		providers:                []Provider_Status,
		ready_for_local_practice: bool,
	}
	res.data = to_json(Data{
		engine_version           = ENGINE_VERSION,
		schema_version           = SCHEMA_VERSION,
		catalog_version          = CATALOG_VERSION,
		catalog_available        = catalog_err == nil && len(problems) >= MIN_CATALOG_PROBLEMS,
		catalog_problem_count    = len(problems),
		workspace_accessible     = workspace_accessible,
		workspace_initialized    = os.is_file(manifest_path(ctx.workspace)),
		event_log_readable       = store.tail_warning == "",
		odin_compiler_available  = odin_available,
		providers                = providers,
		ready_for_local_practice = ready,
	})
	if !ready {
		append(&res.next_actions, "fix the reported workspace, compiler, or catalogue problem before local practice")
	}
	if p.check_accounts {
		append(&res.warnings, "account verification is not performed by the deterministic engine; use each provider's explicit status command")
		append(&res.next_actions, "run the provider status command only when account verification is wanted")
	}
	return
}
