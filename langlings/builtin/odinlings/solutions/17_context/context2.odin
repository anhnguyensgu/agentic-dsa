// context2.odin
package main

import "core:log"

main :: proc() {
	context.logger = log.create_console_logger(lowest = .Info, opt = {.Level})
	defer log.destroy_console_logger(context.logger)

	log.info("starting up")
	log.debug("you shouldn't see this one")
	log.warnf("fuel at %d%%", 5)
}
