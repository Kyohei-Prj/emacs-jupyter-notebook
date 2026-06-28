# Makefile — Emacs Jupyter Notebook build orchestration

# Find all .el files recursively in eln/
EL_FILES := $(shell find eln -name '*.el' -type f)

# Module files: everything in eln/ subdirectories (eln/*/).el
MODULE_EL_FILES := $(shell find eln -mindepth 2 -name '*.el' -type f | sort)

# Main entry point: eln/ejn.el (compiled last, has require stubs for modules)
MAIN_EL_FILE := eln/ejn.el

.PHONY: compile clean lint test

compile:
	emacs -batch -f batch-byte-compile $(MODULE_EL_FILES)
	emacs -batch -f batch-byte-compile $(MAIN_EL_FILE)

clean:
	find eln -name '*.elc' -type f -delete
	rm -rf eln/eln/

lint:
	@fail=0; for f in $(EL_FILES); do \
		emacs -batch --eval "(require 'elint)" \
			--eval "(elint-file \"$$f\")" 2>&1 || fail=1; \
	done; \
	exit $$fail

# Find all test files (files ending in -test.el) in eln/
TEST_FILES := $(shell find eln -name '*-test.el' -type f)

test:
	emacs -batch -L eln/ -l ert -l ejn-test -f ert-run-tests-batch-and-exit
