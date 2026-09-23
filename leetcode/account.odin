package main

import "core:encoding/json"
import "core:fmt"

cmd_account :: proc(o: Options) -> Error {
	if o.offline {fmt.eprintln("account queries require an online connection"); return .Usage}
	cfg := request_credentials(o.command != "stats" || len(o.positionals) == 0) or_return
	vars := jobject()
	query := ""
	key := ""
	switch o.command {
	case "submissions":
		slug := resolve_slug(o, o.positionals[0]) or_return
		vars["slug"], vars["offset"], vars["limit"] =
			slug, json.Integer(o.skip), json.Integer(o.limit)
		query = `query($slug:String!,$offset:Int!,$limit:Int!) { questionSubmissionList(questionSlug:$slug,offset:$offset,limit:$limit) { lastKey hasNext submissions { id title titleSlug statusDisplay lang runtime timestamp url isPending memory } } }`
		key = "questionSubmissionList"
	case "submission":
		id := o.positionals[0]
		if !digits(id) {return .Usage}
		vars["id"] = json.Integer(jint(json.Value(id)))
		query = `query($id:Int!) { submissionDetails(submissionId:$id) { id code runtime memory statusCode timestamp lang { name verboseName } question { title titleSlug questionId } runtimeDisplay memoryDisplay } }`
		key = "submissionDetails"
	case "stats":
		username := ""
		if len(o.positionals) > 0 {username = o.positionals[0]} else {
			status := verify_credentials(cfg) or_return
			if !status.signed_in {return .Not_Signed_In}
			username = status.username
		}
		vars["username"] = username
		query = `query($username:String!) { matchedUser(username:$username) { username profile { ranking reputation } submitStatsGlobal { acSubmissionNum { difficulty count submissions } totalSubmissionNum { difficulty count submissions } } } }`
		key = "matchedUser"
	}
	data := graphql(query, vars, cfg) or_return
	result := jget(data, key)
	if _, ok := result.(json.Object); !ok {return .Not_Found}
	if o.json {print_json(result); return nil}
	switch o.command {
	case "submissions":
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
	case "submission":
		fmt.printf(
			"Submission %d | status %d | %s | %s\n\n%s\n",
			jint(jget(result, "id")),
			jint(jget(result, "statusCode")),
			jstr(jget(result, "runtimeDisplay")),
			jstr(jget(result, "memoryDisplay")),
			jstr(jget(result, "code")),
		)
	case "stats":
		fmt.printf(
			"%s | rank %d\n",
			jstr(jget(result, "username")),
			jint(jget(jget(result, "profile"), "ranking")),
		)
		for s in jarray(jget(jget(result, "submitStatsGlobal"), "acSubmissionNum")) {fmt.printf("%-6s %d solved\n", jstr(jget(s, "difficulty")), jint(jget(s, "count")))}
	}
	return nil
}
