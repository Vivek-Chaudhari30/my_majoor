# Makefile — Majoor
# xcodegen-managed project
# Bundle ID:        com.majoor.app
# Development Team: 27WFRH77ZP

SCHEME              := Majoor
PROJECT             := Majoor.xcodeproj
ARCHIVE_PATH        := build/Majoor.xcarchive
EXPORT_OPTIONS      := build/ExportOptions.plist
EXPORT_OUTPUT       := build/MajoorApp
DEVELOPMENT_TEAM    := 27WFRH77ZP
BUNDLE_ID           := com.majoor.app
APPSTORE_ENTITLEMENTS := Majoor/Majoor-AppStore.entitlements

.PHONY: help generate build build-appstore validate upload clean eval

# ──────────────────────────────────────────────────────────────
# help — list available targets
# ──────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  Majoor — available make targets"
	@echo ""
	@echo "  generate       Regenerate Majoor.xcodeproj from project.yml via xcodegen"
	@echo "  build          Build the app (Debug) using xcodebuild"
	@echo "  build-appstore Archive the app for App Store submission"
	@echo "  validate       Validate the archive with altool (fill in credentials first)"
	@echo "  upload         Export and upload the archive to App Store Connect"
	@echo "  clean          Remove the build/ directory"
	@echo "  eval           Run the Python eval harness at evals/run_eval.py"
	@echo ""

# ──────────────────────────────────────────────────────────────
# generate — regenerate the Xcode project from project.yml
# ──────────────────────────────────────────────────────────────
generate:
	xcodegen generate

# ──────────────────────────────────────────────────────────────
# build — debug build
# ──────────────────────────────────────────────────────────────
build:
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug

# ──────────────────────────────────────────────────────────────
# build-appstore — create an App Store archive
# ──────────────────────────────────────────────────────────────
build-appstore:
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration AppStore \
		-archivePath $(ARCHIVE_PATH) \
		CODE_SIGN_IDENTITY='Apple Distribution' \
		CODE_SIGN_STYLE=Automatic \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) \
		CODE_SIGN_ENTITLEMENTS=$(APPSTORE_ENTITLEMENTS)

# ──────────────────────────────────────────────────────────────
# validate — validate the archive before submission
# NOTE: fill in --username and --password (or use @keychain:) below
# ──────────────────────────────────────────────────────────────
validate:
	# TODO: replace <APPLE_ID> and <APP_SPECIFIC_PASSWORD> with real credentials
	# Use --password @keychain:AC_PASSWORD to read from Keychain securely.
	xcrun altool --validate-app \
		--file $(ARCHIVE_PATH)/Products/Applications/Majoor.app \
		--type osx \
		--username "<APPLE_ID>" \
		--password "<APP_SPECIFIC_PASSWORD>"

# ──────────────────────────────────────────────────────────────
# upload — export the archive and upload to App Store Connect
# NOTE: build/ExportOptions.plist must exist before running this.
#       Create it via Xcode Organizer or write it manually.
# ──────────────────────────────────────────────────────────────
upload:
	@if [ ! -f $(EXPORT_OPTIONS) ]; then \
		echo "ERROR: $(EXPORT_OPTIONS) not found. Create it first (see Xcode Organizer or Apple docs)."; \
		exit 1; \
	fi
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportOptionsPlist $(EXPORT_OPTIONS) \
		-exportPath $(EXPORT_OUTPUT)

# ──────────────────────────────────────────────────────────────
# clean — remove build artifacts
# ──────────────────────────────────────────────────────────────
clean:
	rm -rf build/

# ──────────────────────────────────────────────────────────────
# eval — run the Python eval harness
# ──────────────────────────────────────────────────────────────
eval:
	python3 evals/run_eval.py
