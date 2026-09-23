.PHONY: build test test-unit test-integration test-learning test-mcp test-packaging package-plugin install uninstall clean
PREFIX ?= $(HOME)/.local

build:
	mkdir -p bin
	odin build leetcode -out:bin/leetcode -o:speed
	odin build kattis -out:bin/kattis -o:speed
	odin build algolearn -out:bin/algolearn -o:speed

test-unit:
	odin test leetcode -out:/tmp/leetcode-unit-tests
	odin test algolearn/learning -out:/tmp/algolearn-unit-tests -define:ODIN_TEST_TRACK_MEMORY=false

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

test: test-unit test-integration test-learning test-mcp test-packaging

install: build
	install -d "$(PREFIX)/bin"
	install -m 755 bin/leetcode "$(PREFIX)/bin/leetcode"
	install -m 755 bin/kattis "$(PREFIX)/bin/kattis"
	install -m 755 bin/algolearn "$(PREFIX)/bin/algolearn"

uninstall:
	rm -f "$(PREFIX)/bin/leetcode" "$(PREFIX)/bin/kattis" "$(PREFIX)/bin/algolearn"

clean:
	rm -f bin/leetcode bin/kattis bin/algolearn plugins/codex/algorithm-learning/bin/algolearn
