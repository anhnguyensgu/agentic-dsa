.PHONY: build check test test-unit test-integration test-learning test-mcp test-packaging package-plugin install uninstall clean

PREFIX ?= $(HOME)/.local
ODIN_FLAGS := -vet -strict-style

build:
	mkdir -p bin
	odin build leetcode -out:bin/leetcode -o:speed $(ODIN_FLAGS)
	odin build kattis -out:bin/kattis -o:speed $(ODIN_FLAGS)
	odin build algolearn -out:bin/algolearn -o:speed $(ODIN_FLAGS)

# Type-check every package, including the libraries that have no entry point.
check:
	odin check leetcode $(ODIN_FLAGS)
	odin check kattis $(ODIN_FLAGS)
	odin check algolearn $(ODIN_FLAGS)
	odin check algolearn/learning -no-entry-point $(ODIN_FLAGS)
	odin check safeio -no-entry-point $(ODIN_FLAGS)

test-unit:
	mkdir -p bin
	odin test leetcode -out:bin/leetcode-tests $(ODIN_FLAGS)
	odin test algolearn/learning -out:bin/learning-tests $(ODIN_FLAGS)

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
	install -m 755 bin/leetcode "$(PREFIX)/bin/leetcode"
	install -m 755 bin/kattis "$(PREFIX)/bin/kattis"
	install -m 755 bin/algolearn "$(PREFIX)/bin/algolearn"

uninstall:
	rm -f "$(PREFIX)/bin/leetcode" "$(PREFIX)/bin/kattis" "$(PREFIX)/bin/algolearn"

clean:
	rm -rf bin plugins/codex/algorithm-learning/bin/algolearn
