.PHONY: all compile lint lint-pkg lint-checkdoc lint-declare test clean help

all: compile lint test

compile:
	eask compile

lint: lint-pkg lint-checkdoc lint-declare

lint-pkg:
	eask lint package ejn.el

lint-checkdoc:
	eask lint checkdoc lisp/*.el test/*.el

lint-declare:
	eask lint declare lisp/*.el test/*.el

test:
	eask test ert test/*.el

clean:
	eask clean all

help:
	@echo "EJN Makefile targets:"
	@echo "  compile       - Byte-compile all .el files"
	@echo "  lint          - Run all linters"
	@echo "  lint-pkg      - Run package-lint on ejn.el"
	@echo "  lint-checkdoc - Run checkdoc on lisp/ and test/"
	@echo "  lint-declare  - Run check-declare on lisp/ and test/"
	@echo "  test          - Run ERT test suite"
	@echo "  clean         - Remove build artifacts"
	@echo "  all           - Compile, lint, and test"
