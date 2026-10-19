package judge

import "core:testing"

@(private = "file")
noop :: proc(o: Options) -> Error {
	return nil
}

// A minimal provider: one command with an alias, one value flag, and a
// validate hook, which is all the shared parser needs.
@(private = "file")
fixture :: proc() -> Provider {
	@(static) commands := [?]Command_Spec {
		{
			names = {"show", "fetch"},
			min_args = 1,
			max_args = 1,
			flags = {.Json, .Timeout},
			handler = noop,
		},
		{names = {"list"}, max_args = 1, flags = {.Limit, .Page}, handler = noop},
	}
	return {
		name = "fixture",
		version = "fixture 1.0",
		usage = "usage: fixture",
		commands = commands[:],
		defaults = {limit = 20},
		validate = proc(o: Options) -> Error {
			return .Usage if o.command == 1 && o.page > 9 else nil
		},
		messages = #partial [Error]string{.Not_Found = "fixture problem is missing"},
	}
}

@(test)
parser_resolves_commands_flags_and_builtins :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	p := fixture()

	o, err := parse_options(p, {"fetch", "two", "--json", "--timeout", "5"})
	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, o.builtin, Builtin.None)
	testing.expect_value(t, o.command, 0)
	testing.expect_value(t, positional(o, 0), "two")
	testing.expect_value(t, positional(o, 1), "")
	testing.expect(t, o.json && o.timeout == 5 && o.seen == {.Json, .Timeout})
	testing.expect_value(t, o.limit, 20)
	testing.expect_value(t, o.workspace, "problems")

	o, err = parse_options(p, {"list", "--", "--not-a-flag"})
	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, positional(o, 0), "--not-a-flag")

	o, err = parse_options(p, {"no-such-command", "--help"})
	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, o.builtin, Builtin.Help)

	o, err = parse_options(p, {"capabilities", "--json"})
	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, o.builtin, Builtin.Capabilities)

	invalid := [][]string {
		{},
		{"no-such-command"},
		{"show"},
		{"show", "a", "b"},
		{"show", "a", "--page", "1"}, // known flag the command does not support
		{"show", "a", "--bogus"},
		{"show", "a", "--timeout"},
		{"show", "a", "--timeout", "0"},
		{"list", "--limit", "101"},
		{"list", "--page", "-1"},
		{"list", "--page", "10"}, // rejected by the provider's validate hook
		{"version", "extra"},
	}
	for args in invalid {
		_, e := parse_options(p, args)
		testing.expectf(t, e == .Usage, "accepted %v", args)
	}
}

@(test)
errors_share_messages_and_exit_codes :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	p := fixture()

	testing.expect_value(t, error_message(p, .Not_Found), "fixture problem is missing")
	testing.expect_value(t, error_message(p, .Network), DEFAULT_MESSAGES[.Network])
	testing.expect_value(
		t,
		error_message(p, .Usage),
		"invalid arguments; use `algo judge fixture help`",
	)
	for err in Error {
		if err != .None && err != .Usage {
			testing.expectf(t, error_message(p, err) != "", "%v has no message", err)
		}
	}

	testing.expect_value(t, exit_code(.None), 0)
	testing.expect_value(t, exit_code(.Network), 1)
	testing.expect_value(t, exit_code(.Invalid_Problem_Id), 2)
	testing.expect_value(t, exit_code(.Judge_Failed), 3)
	testing.expect_value(t, exit_code(.Samples_Failed), 3)
	testing.expect_value(t, exit_code(.Unchecked), 4)

	testing.expect_value(t, run_provider(p, nil), 2)
	testing.expect_value(t, run_provider(p, {"version"}), 0)
	testing.expect_value(t, run_provider(p, {"show", "x"}), 0)
}

@(test)
comparators_and_outcomes :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	testing.expect(t, compare_exact("1\n", "1\n") && !compare_exact("1", "1\n"))
	testing.expect(t, compare_trimmed("  1 2\n", "1 2") && !compare_trimmed("1  2", "1 2"))
	testing.expect(t, compare_tokens("1  2\n3", "1 2 3") && !compare_tokens("1 2", "1 2 3"))
	testing.expect(t, compare_trailing("a\r\nb \n\n", "a\nb") && !compare_trailing(" a", "a"))

	tally: Tally
	testing.expect_value(t, outcome(tally), "unverified")
	tally_case(&tally, true, true)
	testing.expect_value(t, outcome(tally), "passed")
	tally_case(&tally, false, false)
	testing.expect_value(t, outcome(tally), "unverified")
	tally_case(&tally, true, false)
	testing.expect_value(t, outcome(tally), "failed")
	testing.expect_value(t, tally, Tally{verified_passed = 1, verified_failed = 1, unchecked = 1})
}

@(test)
html_and_transport_helpers :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	text, next := between("<a>x</a><a>y</a>", "<a>", "</a>", 5)
	testing.expect_value(t, text, "y")
	testing.expect_value(t, next, 16)
	_, missing := between("abc", "<", ">")
	testing.expect_value(t, missing, -1)

	cells := table_cells(`<tr><td class="c">1</td><td>two</td></tr>`)
	testing.expect_value(t, len(cells), 2)
	testing.expect_value(t, cells[0], "1")
	testing.expect_value(t, strip_tags("<p> a\n &amp;lt; <b>b</b> &ndash; </p>"), "a &lt; b - ")
	testing.expect_value(t, html_text("<p>x &lt; 10<sup>4</sup> &amp; y</p>"), "x < 10^4 & y")
	testing.expect_value(t, html_text("a &ndash; b"), "a &ndash; b")
	testing.expect_value(t, pre_body("\n1\n"), "1\n")

	body, trailer, ok := split_trailer("{}\n200")
	testing.expect(t, ok && body == "{}" && trailer == "200")
	_, trailer, ok = split_trailer("200")
	testing.expect(t, !ok && trailer == "200")
	testing.expect_value(t, url_encode("a b/c~"), "a+b%2Fc~")
	head, tail := split_once("k=v=w", "=")
	testing.expect(t, head == "k" && tail == "v=w")
	testing.expect(t, digits("0123") && !digits("") && !digits("1a"))
}
