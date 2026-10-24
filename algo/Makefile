.PHONY: build check test test-unit test-integration test-learning test-mcp test-packaging install uninstall clean

PREFIX ?= $(HOME)/.local
ODIN_FLAGS := -vet -strict-style

# Older versions installed these names as symlinks to algo. build, install,
# and uninstall remove them; a file of the same name that is not such a
# symlink is left alone.
OLD_ALIASES := leetcode kattis algolearn
remove_old_aliases = for name in $(OLD_ALIASES); do \
	if [ "$$(readlink "$(1)/$$name")" = algo ]; then rm -f "$(1)/$$name"; fi; \
done

build:
	mkdir -p bin
	odin build . -out:bin/algo -o:speed $(ODIN_FLAGS)
	$(call remove_old_aliases,bin)

# Type-check every package, including the libraries that have no entry point.
check:
	odin check . $(ODIN_FLAGS)
	odin check judge -no-entry-point $(ODIN_FLAGS)
	odin check judge/leetcode -no-entry-point $(ODIN_FLAGS)
	odin check judge/kattis -no-entry-point $(ODIN_FLAGS)
	odin check learn -no-entry-point $(ODIN_FLAGS)
	odin check safeio -no-entry-point $(ODIN_FLAGS)

test-unit:
	mkdir -p bin
	odin test judge -out:bin/judge-tests $(ODIN_FLAGS)
	odin test judge/leetcode -out:bin/leetcode-tests $(ODIN_FLAGS)
	odin test learn -out:bin/learn-tests $(ODIN_FLAGS)

test-integration: build
	python3 tests/integration.py
	python3 tests/kattis_integration.py

test-learning: build
	python3 tests/learning_integration.py
	python3 tests/validate_curriculum.py
	python3 tests/teaching_scenarios.py

test-mcp: build
	python3 tests/mcp_protocol.py

test-packaging: build
	python3 tests/packaging.py

test: check test-unit test-integration test-learning test-mcp test-packaging

install: build
	install -d "$(PREFIX)/bin"
	install -m 755 bin/algo "$(PREFIX)/bin/algo"
	$(call remove_old_aliases,$(PREFIX)/bin)

uninstall:
	rm -f "$(PREFIX)/bin/algo"
	$(call remove_old_aliases,$(PREFIX)/bin)

clean:
	rm -rf bin
