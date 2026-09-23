package main

Session :: struct {}

main :: proc() {
	_ = load_session()
}

load_session :: proc() -> Session {
	return Session{}
}

Command :: union {
	Command_Login,
	Command_Fetch,
}

// Dispatch reads the command; only the session is mutable.
execute :: proc(cmd: Command, session: ^Session) {
	switch _ in cmd {
	case Command_Login:
		session^ = login()
	case Command_Fetch:
		fetch(session)
	case:
		return // A nil command means there is nothing to execute.
	}
}
