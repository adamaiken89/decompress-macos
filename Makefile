PRODUCT_NAME = Decompress
SWIFT_FORMAT = xcrun swift-format

.PHONY: build build-strict test format format-check clean release run session check version bump-version

build:
	swift build

build-strict:
	swift build -Xswiftc -strict-concurrency=complete

test:
	swift test --verbose

test-coverage:
	swift test --enable-code-coverage
	@echo ""
	@echo "--- Coverage Report ---"
	@xcrun llvm-cov report \
		.build/debug/DecompressPackageTests.xctest/Contents/MacOS/DecompressPackageTests \
		--ignore-filename-regex='Tests/|.build/' \
		--instr-profile=.build/debug/codecov/default.profdata \
		--use-color 2>/dev/null || echo "Coverage data not available (run test-coverage after a full build)"

format:
	@if command -v $(SWIFT_FORMAT) >/dev/null 2>&1; then \
		$(SWIFT_FORMAT) format --in-place --recursive Sources/ Tests/; \
		echo "Formatted Sources/ and Tests/"; \
	else \
		echo "$(SWIFT_FORMAT) not found. Is Xcode.app selected via xcode-select?"; \
		exit 1; \
	fi

format-check:
	@if command -v $(SWIFT_FORMAT) >/dev/null 2>&1; then \
		$(SWIFT_FORMAT) lint --recursive Sources/ Tests/; \
	else \
		echo "$(SWIFT_FORMAT) not found. Is Xcode.app selected via xcode-select?"; \
		exit 1; \
	fi

clean:
	swift package clean
	rm -rf .build

release:
	swift build -c release

version:
	@echo "Version: $$(plutil -extract CFBundleShortVersionString raw support/Info.plist 2>/dev/null || echo '0.0.0')"
	@echo "Build:   $$(plutil -extract CFBundleVersion raw support/Info.plist 2>/dev/null || echo '0')"

bump-version:
	@if [ -z "$(V)" ]; then echo "Usage: make bump-version V=1.2.3"; exit 1; fi
	plutil -replace CFBundleShortVersionString -string "$(V)" support/Info.plist
	@echo "Version bumped to $(V)"

run: build
	rm -rf "$(PRODUCT_NAME).app"
	./scripts/make-app-bundle.sh ".build/debug/$(PRODUCT_NAME)"
	open "$(PRODUCT_NAME).app"

check: format format-check build-strict test-coverage

session:
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "Usage: make session <branch-name>"; \
		exit 1; \
	fi
	./scripts/start-session.sh $(filter-out $@,$(MAKECMDGOALS))

%:
	@true
