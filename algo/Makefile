.PHONY: build check test test-unit test-integration test-learning test-mcp test-packaging package-plugin install uninstall clean

PREFIX ?= $(HOME)/.local
ODIN_FLAGS := -vet -strict-style

# One executable; the legacy names are symlinks that select a command group.
LEGACY_NAMES := leetcode kattis algolearn

build:
	mkdir -p bin
	odin build . -out:bin/algo -o:speed $(ODIN_FLAGS)
	for name in $(LEGACY_NAMES); do ln -sf algo bin/$$name; done

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

package-plugin: build
	python3 scripts/package_plugin.py

test-packaging: package-plugin
	python3 tests/packaging.py

test: check test-unit test-integration test-learning test-mcp test-packaging

install: build
	install -d "$(PREFIX)/bin"
	install -m 755 bin/algo "$(PREFIX)/bin/algo"
	for name in $(LEGACY_NAMES); do ln -sf algo "$(PREFIX)/bin/$$name"; done

uninstall:
	rm -f "$(PREFIX)/bin/algo"
	for name in $(LEGACY_NAMES); do rm -f "$(PREFIX)/bin/$$name"; done

clean:
	rm -rf bin plugins/codex/algorithm-learning/bin/algo
