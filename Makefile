.PHONY: all deps compile lint lint-pkg lint-checkdoc lint-declare test clean help

all: compile lint test

deps:
	eask install-deps --dev

compile: deps
	@OUTPUT=$$(eask compile 2>&1) && exit 0 || { \
		echo "$$OUTPUT"; \
		if echo "$$OUTPUT" | grep -q "Unknown type jupyter-kernel-client" && \
		   ! echo "$$OUTPUT" | grep -v "jupyter-kernel-client" | grep -qi "error"; then \
			exit 0; else exit 1; fi; \
	}

lint: lint-pkg lint-checkdoc lint-declare

lint-pkg:
	eask lint package ejn.el

lint-checkdoc:
	eask lint checkdoc lisp/*.el test/*.el

lint-declare:
	eask lint declare lisp/*.el test/*.el

test: deps
	eask test ert test/*.el

clean:
	eask clean all

help:
	@echo "EJN Makefile targets:"
	@echo "  deps          - Install dependencies"
	@echo "  compile       - Byte-compile all .el files (installs deps first)"
	@echo "  lint          - Run all linters"
	@echo "  lint-pkg      - Run package-lint on ejn.el"
	@echo "  lint-checkdoc - Run checkdoc on lisp/ and test/"
	@echo "  lint-declare  - Run check-declare on lisp/ and test/"
	@echo "  test          - Run ERT test suite (installs deps first)"
	@echo "  clean         - Remove build artifacts"
	@echo "  all           - Compile, lint, and test"
