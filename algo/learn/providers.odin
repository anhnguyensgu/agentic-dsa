package learn

// Provider discovery is conservative: an implemented adapter is separate from
// one that is available now. The doctor checks versions and paths only; it
// never starts a login or uploads source.

import "../safeio"
import "core:os"
import "core:strings"
import "core:time"

PROVIDERS :: [?]string{"leetcode", "kattis"}

// Languages every provider supports through the local runner.
LOCAL_LANGUAGES := []string{"odin"}

// find_executable looks in the workspace (bin/ first), then on PATH. It is
// used for the Odin compiler; providers run inside this binary.
find_executable :: proc(workspace, name: string) -> string {
	for candidate in ([?]string{join(workspace, "bin", name), join(workspace, name)}) {
		if os.is_file(candidate) {
			return candidate
		}
	}
	return find_on_path(name)
}

find_on_path :: proc(name: string) -> string {
	for dir in strings.split(os.get_env("PATH", context.allocator), ":") {
		if candidate := join(dir, name); os.is_file(candidate) {
			return candidate
		}
	}
	return ""
}

// self_executable is the running algo binary. Provider adapters run as
// `<self> judge <provider> ...`, so they always match this engine's build and
// a crash or hang in network code never takes the engine down with it.
self_executable :: proc() -> string {
	if path, err := os.get_executable_path(context.allocator); err == nil && path != "" {
		return path
	}
	if len(os.args) == 0 {
		return ""
	}
	// Fall back to argv[0]: a path, or a bare name found on PATH.
	if name := os.args[0]; strings.contains(name, "/") {
		path, err := os.get_absolute_path(name, context.allocator)
		return path if err == nil else ""
	} else {
		return find_on_path(name)
	}
}

// provider_command is the argument-vector prefix that runs a provider
// adapter. Provider names can come from an imported event log, so only known
// providers are ever turned into a command.
provider_command :: proc(provider: string) -> (command: [dynamic]string, err: Op_Error) {
	known := PROVIDERS
	self := self_executable()
	if !contains(known[:], provider) || self == "" {
		return nil, fail(.Unsupported_Capability, "the compatible provider adapter is unavailable")
	}
	command = make([dynamic]string)
	append(&command, self, "judge", provider)
	return command, nil
}

provider_version :: proc(provider: string) -> string {
	command, err := provider_command(provider)
	if err != nil {
		return ""
	}
	append(&command, "version")
	run := safeio.run(command[:], timeout = 3 * time.Second, output_limit = 16 * 1024)
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

op_doctor :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Doctor_Params) or_return
	providers := make([]Provider_Status, len(PROVIDERS))
	self := self_executable()
	for name, i in PROVIDERS {
		providers[i] = provider_status(name, self, provider_version(name))
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
	res.data = to_json(
		Data {
			engine_version = ENGINE_VERSION,
			schema_version = SCHEMA_VERSION,
			catalog_version = CATALOG_VERSION,
			catalog_available = catalog_err == nil && len(problems) >= MIN_CATALOG_PROBLEMS,
			catalog_problem_count = len(problems),
			workspace_accessible = workspace_accessible,
			workspace_initialized = os.is_file(manifest_path(ctx.workspace)),
			event_log_readable = store.tail_warning == "",
			odin_compiler_available = odin_available,
			providers = providers,
			ready_for_local_practice = ready,
		},
	)
	if !ready {
		append(
			&res.next_actions,
			"fix the reported workspace, compiler, or catalogue problem before local practice",
		)
	}
	if p.check_accounts {
		append(
			&res.warnings,
			"account verification is not performed by the deterministic engine; use each provider's explicit status command",
		)
		append(
			&res.next_actions,
			"run the provider status command only when account verification is wanted",
		)
	}
	return
}
