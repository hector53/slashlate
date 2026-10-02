.PHONY: build test app run clean

build:
	swift build

test:
	swift test

app:
	bash scripts/build-app.sh

run:
	bash scripts/run-app.sh

clean:
	rm -rf .build build
