.DEFAULT_GOAL := upload-release

VERSION ?= 0.1.1
RELEASE_TAG ?= v$(VERSION)
RELEASE_ZIP ?= $(lastword $(sort $(wildcard build/macos-release-*/XcodeMini-$(VERSION)-macos-notarized.zip)))
SWIFT ?= swift
SWIFTLINT ?= swiftlint
FSD_IOS_REF ?= v0.4.0
FSD_IOS_COMMIT ?= 38dc4261e589d1754820aac6c79de5310e0d0ac3
FSD_IOS_DIR ?= .fsd-ios-tooling
FSD_IOS_CLI ?= $(FSD_IOS_DIR)/tools/fsd-ios.swift

.PHONY: upload-release lint lint-swift lint-architecture setup-fsd-tooling

lint: lint-swift lint-architecture

lint-swift:
	@command -v "$(SWIFTLINT)" > /dev/null || { echo 'SwiftLint is not installed. Install it with `brew install swiftlint`.' >&2; exit 1; }
	$(SWIFTLINT) lint --strict --config .swiftlint.yml

lint-architecture:
	@test -f "$(FSD_IOS_CLI)" || { echo 'FSD iOS tooling is missing. Run `make setup-fsd-tooling` first.' >&2; exit 1; }
	$(SWIFT) "$(FSD_IOS_CLI)" lint --config .fsd-ios.yml --strict --architecture

setup-fsd-tooling:
	@test -d "$(FSD_IOS_DIR)/.git" || { git clone --quiet --depth 1 --branch "$(FSD_IOS_REF)" https://github.com/SoundBlaster/FSD.git "$(FSD_IOS_DIR)" && git -C "$(FSD_IOS_DIR)" checkout --quiet --detach "$(FSD_IOS_COMMIT)"; }
	@$(SWIFT) "$(FSD_IOS_CLI)" version

upload-release:
	@test -n "$(RELEASE_ZIP)" -a -f "$(RELEASE_ZIP)" || { echo "No notarized ZIP found for version $(VERSION). Run Scripts/release-macos.sh first or set RELEASE_ZIP." >&2; exit 1; }
	@gh release view "$(RELEASE_TAG)" >/dev/null
	gh release upload --clobber "$(RELEASE_TAG)" "$(RELEASE_ZIP)"
