APP_NAME := ClipboardMarkup

.PHONY: setup build run verify test clean

setup:
	swift package resolve

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
