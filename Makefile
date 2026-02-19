APP_NAME = TallysPerfectPomo
BUNDLE_NAME = Tally's Perfect Pomo.app
BUILD_DIR = .build

.PHONY: build release bundle run clean

# Debug build
build:
	swift build

# Release build
release:
	swift build -c release

# Create .app bundle from release build
bundle: release
	@echo "Creating app bundle..."
	@rm -rf "$(BUNDLE_NAME)"
	@mkdir -p "$(BUNDLE_NAME)/Contents/MacOS"
	@mkdir -p "$(BUNDLE_NAME)/Contents/Resources"
	@cp "$(BUILD_DIR)/release/$(APP_NAME)" "$(BUNDLE_NAME)/Contents/MacOS/"
	@cp Resources/Info.plist "$(BUNDLE_NAME)/Contents/"
	@echo "Created $(BUNDLE_NAME)"

# Run debug build directly (no .app bundle needed)
run: build
	"$(BUILD_DIR)/debug/$(APP_NAME)"

# Run from .app bundle
run-app: bundle
	open "$(BUNDLE_NAME)"

# Run tests
test:
	swift test

clean:
	swift package clean
	rm -rf "$(BUNDLE_NAME)"
