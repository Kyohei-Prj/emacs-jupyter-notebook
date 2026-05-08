.PHONY: all compile lint lint-pkg lint-format test clean help

all: compile lint test

compile:
	eask compile

lint: lint-pkg lint-format

lint-pkg:
	eask lint package

lint-format:
	eask format --check

test:
	eask test ert test/*.el

clean:
	eask clean all

help:
	@echo "EJN Makefile targets:"
	@echo "  compile     - Byte-compile all .el files"
	@echo "  lint        - Run all linters (package + format)"
	@echo "  lint-pkg    - Run package-lint"
	@echo "  lint-format - Check code formatting"
	@echo "  test        - Run ERT test suite"
	@echo "  clean       - Remove build artifacts"
	@echo "  all         - Compile, lint, and test"
