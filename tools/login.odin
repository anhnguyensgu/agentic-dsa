package main

Command_Login :: struct {
	callback: proc(session: Session),
}

login :: proc() -> Session {
	return Session{}
}
