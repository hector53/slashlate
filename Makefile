.PHONY: build app run clean

build:
	swift build

app:
	bash scripts/build-app.sh

run:
	bash scripts/run-app.sh

clean:
	rm -rf .build build
