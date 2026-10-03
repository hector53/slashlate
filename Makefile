.PHONY: build test app run install clean

build:
	swift build

test:
	swift test

app:
	bash scripts/build-app.sh

run:
	bash scripts/run-app.sh

install:
	bash scripts/install-app.sh

clean:
	rm -rf .build build
