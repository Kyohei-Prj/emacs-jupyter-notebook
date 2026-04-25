.PHONY: install test lint

install:
	eask install-deps

test:
	eask test buttercup

lint:
	eask lint package
