// context2.odin
//
// `log.info` and friends write to `context.logger`, and the default logger
// throws everything away.
package main

import "core:log"

main :: proc() {
	// TODO: Install a console logger here, and destroy it when `main` ends.
	// Show only the level in front of each message (the `opt` parameter) and
	// leave out debug messages (the `lowest` parameter).

	log.info("starting up")
	log.debug("you shouldn't see this one")
	log.warnf("fuel at %d%%", 5)
}
