.PHONY: install test lint

install:
	eask install-deps

test:
	eask test ert ./test/*.el

lint:
	eask lint package
