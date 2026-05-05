.PHONY: install test lint

install:
	eask install-deps

test:
	eask test ert

lint:
	eask lint package
