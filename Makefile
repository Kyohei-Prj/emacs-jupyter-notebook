.PHONY: all compile lint lint-pkg test clean help

all: compile lint test

compile:
	eask compile

lint: lint-pkg

lint-pkg:
	eask lint package ejn.el


test:
	eask test ert test/*.el

clean:
	eask clean all

help:
	@echo "EJN Makefile targets:"
	@echo "  compile     - Byte-compile all .el files"
	@echo "  lint        - Run all linters (package)"
	@echo "  lint-pkg    - Run package-lint"
	@echo "  test        - Run ERT test suite"
	@echo "  clean       - Remove build artifacts"
	@echo "  all         - Compile, lint, and test"
