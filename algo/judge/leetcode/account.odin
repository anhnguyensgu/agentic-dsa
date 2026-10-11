package leetcode

import "core:encoding/json"
import "core:fmt"
import judge ".."

SUBMISSIONS_QUERY :: `query($slug:String!,$offset:Int!,$limit:Int!) { questionSubmissionList(questionSlug:$slug,offset:$offset,limit:$limit) { lastKey hasNext submissions { id title titleSlug statusDisplay lang runtime timestamp url isPending memory } } }`
SUBMISSION_QUERY :: `query($id:Int!) { submissionDetails(submissionId:$id) { id code runtime memory statusCode timestamp lang { name verboseName } question { title titleSlug questionId } runtimeDisplay memoryDisplay } }`
STATS_QUERY :: `query($username:String!) { matchedUser(username:$username) { username profile { ranking reputation } submitStatsGlobal { acSubmissionNum { difficulty count submissions } totalSubmissionNum { difficulty count submissions } } } }`

// cmd_account handles submissions, submission, and stats. Only public
// statistics for an explicitly named user work without a session.
cmd_account :: proc(o: Options) -> Error {
	if o.offline {
		fmt.eprintln("account queries require an online connection")
		return .Usage
	}
	named_user := Command(o.command) == .Stats && len(o.positionals) > 0
	cfg := request_credentials(required = !named_user) or_return

	vars := jobject()
	query, key: string
	#partial switch Command(o.command) {
	case .Submissions:
		slug := resolve_slug(o, o.positionals[0]) or_return
		vars["slug"], vars["offset"], vars["limit"] = slug, json.Integer(o.skip), json.Integer(o.limit)
		query, key = SUBMISSIONS_QUERY, "questionSubmissionList"
	case .Submission:
		id := o.positionals[0]
		if !judge.digits(id) {
			return .Usage
		}
		vars["id"] = json.Integer(jint(id))
		query, key = SUBMISSION_QUERY, "submissionDetails"
	case .Stats:
		username := o.positionals[0] if named_user else ""
		if !named_user {
			status := verify_credentials(cfg) or_return
			if !status.signed_in {
				return .Not_Signed_In
			}
			username = status.username
		}
		vars["username"] = username
		query, key = STATS_QUERY, "matchedUser"
	}

	data := graphql(query, vars, cfg) or_return
	result := jget(data, key)
	if _, ok := result.(json.Object); !ok {
		return .Not_Found
	}
	if o.json {
		judge.print_json(result)
		return nil
	}

	#partial switch Command(o.command) {
	case .Submissions:
		for s in jarray(jget(result, "submissions")) {
			fmt.printf(
				"%s  %-20s %-12s %s  %s\n",
				jstr(jget(s, "id")),
				jstr(jget(s, "statusDisplay")),
				jstr(jget(s, "lang")),
				jstr(jget(s, "runtime")),
				jstr(jget(s, "memory")),
			)
		}
		fmt.printf("More: %v (next --skip %d)\n", jbool(jget(result, "hasNext")), o.skip + o.limit)
	case .Submission:
		fmt.printf(
			"Submission %d | status %d | %s | %s\n\n%s\n",
			jint(jget(result, "id")),
			jint(jget(result, "statusCode")),
			jstr(jget(result, "runtimeDisplay")),
			jstr(jget(result, "memoryDisplay")),
			jstr(jget(result, "code")),
		)
	case .Stats:
		fmt.printf("%s | rank %d\n", jstr(jget(result, "username")), jint(jget(jget(result, "profile"), "ranking")))
		for s in jarray(jget(jget(result, "submitStatsGlobal"), "acSubmissionNum")) {
			fmt.printf("%-6s %d solved\n", jstr(jget(s, "difficulty")), jint(jget(s, "count")))
		}
	}
	return nil
}
