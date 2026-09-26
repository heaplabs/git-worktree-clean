.PHONY: test test-bash32 lint check

test:
	bats tests/

test-bash32:
	WT_BASH=/bin/bash bats tests/

lint:
	shellcheck -s bash git-wt-clean tests/bin/gh

check: lint test
