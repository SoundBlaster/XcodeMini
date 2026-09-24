VERSION ?= 0.1.0
RELEASE_TAG ?= v$(VERSION)
RELEASE_ZIP ?= $(lastword $(sort $(wildcard build/macos-release-*/XcodeMini-$(VERSION)-macos-notarized.zip)))

.PHONY: upload-release
upload-release:
	@test -n "$(RELEASE_ZIP)" -a -f "$(RELEASE_ZIP)" || { echo "No notarized ZIP found for version $(VERSION). Run Scripts/release-macos.sh first or set RELEASE_ZIP." >&2; exit 1; }
	@gh release view "$(RELEASE_TAG)" >/dev/null
	gh release upload --clobber "$(RELEASE_TAG)" "$(RELEASE_ZIP)"
