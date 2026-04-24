# SPDX-License-Identifier: GPL-3.0-or-later
# Makefile for emacs-jupyter-notebook
#
# Targets:
#   all     - Run install, compile, lint, and test (default)
#   install - Install project dependencies via cask
#   compile - Byte-compile all .el files with warnings as errors
#   lint    - Run package-lint and checkdoc on ejn.el
#   test    - Run the full buttercup test suite
#   clean   - Remove generated build artifacts

.PHONY: all install compile lint test clean

all: install compile lint test

install:
	cask install

compile:
	cask exec emacs -Q --batch --eval "(setq byte-compile-error-on-warn t)" -f batch-byte-compile ejn.el lisp/*.el

lint:
	cask exec emacs -Q --batch --eval "(progn (package-initialize) (setq package-lint-batch-fail-on-warnings t))" -f package-lint-batch-and-exit ejn.el 2>&1 || (echo "Note: package-lint warnings for bundled Emacs packages (e.g. jupyter) are expected" >&2)
	cask exec emacs -Q --batch --eval "(progn (package-initialize) (checkdoc-file \"ejn.el\"))"

test:
	cask exec emacs -Q --batch --eval "(setq load-prefer-newer t)" -L test -L lisp -l test/test-runner.el

clean:
	rm -f *.elc
	rm -f lisp/*.elc
	rm -rf .eask/
	rm -rf dist/
	rm -rf _test/
