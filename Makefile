PRODUCT_NAME = Decompress

.PHONY: build test lint clean release run

build:
	swift build

test:
	swift test --verbose

lint:
	swiftlint --strict

lint-fix:
	swiftlint --fix

clean:
	swift package clean
	rm -rf .build

release:
	swift build -c release

run: build
	rm -rf "$(PRODUCT_NAME).app"
	./scripts/make-app-bundle.sh ".build/debug/$(PRODUCT_NAME)"
	open "$(PRODUCT_NAME).app"
