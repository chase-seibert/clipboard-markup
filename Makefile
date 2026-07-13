APP_NAME := ClipboardMarkup
PYTHON ?= python3

.PHONY: setup analytics-config build run verify test clean

setup:
	swift package resolve

analytics-config:
	@$(PYTHON) script/write_analytics_config.py

build:
	swift build

run:
	./script/build_and_run.sh

verify:
	./script/build_and_run.sh --verify

test:
	swift test

clean:
	swift package clean
	rm -rf dist
