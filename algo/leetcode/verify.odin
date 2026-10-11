// Credential verification against leetcode.com's GraphQL endpoint.
//
// HTTPS goes through the shared curl transport in api.odin. No shell is used.
package main

import "core:encoding/json"
import "core:fmt"

GQL_USER_STATUS_QUERY :: `{"query":"query { userStatus { username isSignedIn isPremium } }"}`

User_Status :: struct {
	username:  string,
	signed_in: bool,
	premium:   bool,
}

verify_credentials :: proc(cfg: Config) -> (status: User_Status, err: Error) {
	if !valid_credentials(cfg) {
		return {}, .No_Input
	}
	response, e := http_request("POST", "/graphql/", cfg, GQL_USER_STATUS_QUERY)
	if e != nil { return {}, .Verify_Failed }
	return parse_user_status(transmute([]byte)jencode(response))
}

// A missing/null isSignedIn is not the same as false. Keep this distinction
// at the JSON boundary; the rest of the program works with an ordinary bool.
parse_user_status :: proc(data: []byte) -> (status: User_Status, err: Error) {
	response: struct {
		data: struct {
			user_status: struct {
				username:  string      `json:"username"`,
				signed_in: Maybe(bool) `json:"isSignedIn"`,
				premium:   bool        `json:"isPremium"`,
			} `json:"userStatus"`,
		},
		errors: []struct {message: string},
	}
	// unmarshal asserts on malformed input, so the bytes are validated first.
	if !json.is_valid(data, .JSON) || json.unmarshal(data, &response, .JSON) != nil {
		// Do not dump remote bodies, which can contain sensitive data.
		fmt.eprintln("invalid JSON response from leetcode.com (Cloudflare challenge?)")
		return {}, .Verify_Failed
	}
	signed_in, present := response.data.user_status.signed_in.?
	if !present || len(response.errors) != 0 {
		fmt.eprintln("leetcode.com did not return a valid userStatus")
		return {}, .Verify_Failed
	}
	user := response.data.user_status
	if signed_in && user.username == "" {
		fmt.eprintln("signed-in response did not include a username")
		return {}, .Verify_Failed
	}
	return {username = user.username, signed_in = signed_in, premium = user.premium}, nil
}
