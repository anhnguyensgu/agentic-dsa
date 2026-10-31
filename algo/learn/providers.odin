package learn

// Provider discovery is conservative: an implemented adapter is separate from
// one that is available now. The doctor checks versions and paths only; it
// never starts a login, uploads source, or writes to the workspace.
//
// Everything provider-specific the engine needs is data in PROVIDERS; the
// engine never branches on a provider's name.

import "../safeio"
import "core:os"
import "core:strings"
import "core:time"

Provider_Id :: enum {
	Leetcode,
	Kattis,
	Exercism,
}

// Submit_Style is how submit hands a source to a provider.
Submit_Style :: enum {
	Start_Job_With_Language, // submit-start <slug> <file> --lang <language>: a remote job id
	Start_Job, // submit-start <id> <file> [--lang <language>]: Odin is inferred from the extension
	Upload, // submit <file>: an upload with no remote id and no verdict
}

// Check_Style is how job_check reads a provider's `check --json` output.
Check_Style :: enum {
	None, // the provider reports no verdict
	Raw_Result, // the judge's own result, final once state is SUCCESS (verdict in status_msg)
	State_Verdict, // {state, verdict}
}

Provider_Traits :: struct {
	name:               string,
	title:              string,
	remote_odin:        bool, // the remote judge accepts Odin
	remote_odin_reason: string,
	submit:             Submit_Style,
	check:              Check_Style,
	downloads:          bool, // attempts start from the provider's own download, not a scaffold
	template:           string, // starter source for a fresh scaffold
	test_provenance:    string, // provenance of the tests a downloaded exercise ships with
}

PROVIDERS := [Provider_Id]Provider_Traits {
	.Leetcode = {
		name = "leetcode",
		title = "LeetCode",
		remote_odin_reason = "LeetCode does not offer Odin on its remote judge",
		submit = .Start_Job_With_Language,
		check = .Raw_Result,
		template = LOCAL_TEMPLATE,
	},
	.Kattis = {
		name = "kattis",
		title = "Kattis",
		remote_odin = true,
		remote_odin_reason = "availability still requires an authenticated Kattis account and current judge language support",
		submit = .Start_Job,
		check = .State_Verdict,
		template = KATTIS_TEMPLATE,
	},
	.Exercism = {
		name = "exercism",
		title = "Exercism",
		remote_odin = true,
		remote_odin_reason = "exercism submit uploads an iteration; Exercism shows its test results only on exercism.org",
		submit = .Upload,
		check = .None,
		downloads = true,
		test_provenance = "official_tests",
	},
}

// provider_traits finds a provider by name. Names can come from an imported
// event log, so only known providers are found.
provider_traits :: proc(name: string) -> (traits: Provider_Traits, ok: bool) {
	for p in PROVIDERS {
		if p.name == name {
			return p, true
		}
	}
	return {}, false
}

provider_names :: proc() -> []string {
	names := make([]string, len(PROVIDERS))
	for p, id in PROVIDERS {
		names[id] = p.name
	}
	return names
}

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
	_, known := provider_traits(provider)
	self := self_executable()
	if !known || self == "" {
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

provider_status :: proc(provider: Provider_Traits, path, version: string) -> (s: Provider_Status) {
	s = {
		provider        = provider.name,
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
	s.remote_odin = provider.remote_odin && s.available
	s.remote_odin_reason = provider.remote_odin_reason
	return
}

Doctor_Params :: struct {
	check_accounts: bool,
}

op_doctor :: proc(ctx: ^Context, input: Input, req: Request) -> (res: Result, err: Op_Error) {
	p := params(input, Doctor_Params) or_return
	providers := make([]Provider_Status, len(PROVIDERS))
	self := self_executable()
	for p, id in PROVIDERS {
		providers[id] = provider_status(p, self, provider_version(p.name))
	}
	workspace_accessible := os.is_directory(ctx.workspace)
	odin_available := find_executable(ctx.workspace, "odin") != ""
	ready := workspace_accessible && odin_available

	Data :: struct {
		engine_version:           string,
		schema_version:           int,
		workspace_accessible:     bool,
		odin_compiler_available:  bool,
		providers:                []Provider_Status,
		ready_for_local_practice: bool,
	}
	res.data = to_json(
		Data {
			engine_version = ENGINE_VERSION,
			schema_version = SCHEMA_VERSION,
			workspace_accessible = workspace_accessible,
			odin_compiler_available = odin_available,
			providers = providers,
			ready_for_local_practice = ready,
		},
	)
	if !ready {
		append(
			&res.next_actions,
			"fix the reported workspace or compiler problem before local practice",
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
