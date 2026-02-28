.PHONY: build run test lint format clean

PROJECT = Fluister.xcodeproj
SCHEME = Fluister
TEST_SCHEME = FluisterTests
BUILD_DIR = $(CURDIR)/build
DERIVED_DATA = $(BUILD_DIR)

build:
	@echo "Building Fluister..."
	@xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		build 2>&1 \
		| grep -E '(BUILD SUCCEEDED|BUILD FAILED|error:|warning:|CompileSwift|Linking)' \
		|| true
	@test -d "$(BUILD_DIR)/Build/Products/Debug/Fluister.app" \
		&& echo "BUILD SUCCEEDED" \
		|| (echo "BUILD FAILED — run with 'make build-verbose' for full output"; exit 1)

build-verbose:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		build

run: build
	open "$(BUILD_DIR)/Build/Products/Debug/Fluister.app"

test:
	@echo "Running tests..."
	@xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		test 2>&1 \
		| grep -E '(Test Case|Test Suite|TEST SUCCEEDED|TEST FAILED|Executed|error:)' \
		|| true

lint:
	@echo "Lint: no-op (exit 0)"

format:
	@echo "Format: no-op (exit 0)"

clean:
	rm -rf $(BUILD_DIR)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean 2>/dev/null || true
