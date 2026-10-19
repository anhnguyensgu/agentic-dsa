package judge

import "core:fmt"

// One error enum for every provider: its zero value is nil, so it propagates
// with or_return. Failure sites print the specific cause; run_provider prints
// the one-line summary and maps the error to an exit code.
Error :: enum {
	None,
	Usage,
	Invalid_Problem_Id,
	Invalid_Submission_Id,
	No_Input, // nothing usable on stdin or in a file
	Callback_Failed, // loopback server / browser callback failed
	Verify_Failed, // could not reach or parse the judge's account endpoint
	Not_Signed_In,
	Login_Failed,
	Config_Path, // cannot resolve the credentials location
	Config_Read, // missing, corrupt, or empty credentials
	Config_Write, // could not persist credentials
	Config_Delete, // could not remove credentials
	Network,
	API, // unexpected JSON response
	Markup_Changed, // unexpected HTML page
	Not_Found,
	Offline,
	File,
	Destination_Exists,
	Unsupported,
	Timeout,
	Output_Limit,
	Submit_Rejected,
	Build_Failed,
	Samples_Failed,
	Judge_Failed,
	Not_Accepted,
	Unchecked,
}

DEFAULT_MESSAGES := [Error]string {
	.None                  = "",
	.Usage                 = "", // built from the provider name by error_message
	.Invalid_Problem_Id    = "invalid problem id",
	.Invalid_Submission_Id = "invalid submission id (expected digits)",
	.No_Input              = "no input",
	.Callback_Failed       = "browser login failed",
	.Verify_Failed         = "could not verify session (see details above)",
	.Not_Signed_In         = "not signed in or the session expired; log in again",
	.Login_Failed          = "login failed",
	.Config_Path           = "could not resolve credentials location; check your home directory",
	.Config_Read           = "no usable credentials; log in first",
	.Config_Write          = "failed to save credentials (see details above)",
	.Config_Delete         = "failed to remove credentials (see details above)",
	.Network               = "request failed; check the network and curl installation",
	.API                   = "unexpected response from the judge (the service may have changed)",
	.Markup_Changed        = "could not parse the judge's page; its markup may have changed",
	.Not_Found             = "problem or requested data was not found",
	.Offline               = "data is not cached; fetch it once while online",
	.File                  = "could not read or write the requested file",
	.Destination_Exists    = "destination exists; choose a fresh directory",
	.Unsupported           = "unsupported operation (see details above)",
	.Timeout               = "time limit reached",
	.Output_Limit          = "process output exceeded the 256 KiB limit",
	.Submit_Rejected       = "the judge rejected the submission",
	.Build_Failed          = "solution did not compile",
	.Samples_Failed        = "not every sample passed",
	.Judge_Failed          = "solution did not pass",
	.Not_Accepted          = "submission was not accepted",
	.Unchecked             = "some local cases have no expected output",
}

error_message :: proc(p: Provider, err: Error) -> string {
	if p.messages[err] != "" {
		return p.messages[err]
	}
	if err == .Usage {
		return fmt.tprintf("invalid arguments; use `algo judge %s help`", p.name)
	}
	return DEFAULT_MESSAGES[err]
}

// Documented exit codes, shared by every provider: 0 success, 1 operational
// error, 2 usage, 3 failed solution, 4 local cases without expected results.
exit_code :: proc(err: Error) -> int {
	#partial switch err {
	case .None:
		return 0
	case .Usage, .Invalid_Problem_Id, .Invalid_Submission_Id:
		return 2
	case .Build_Failed, .Samples_Failed, .Judge_Failed, .Not_Accepted:
		return 3
	case .Unchecked:
		return 4
	}
	return 1
}
