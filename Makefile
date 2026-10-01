.PHONY: all build run test install release icon clean

all: build

## Build dist/Curtain.app (universal). ARCH=host for a quicker single-arch build.
build:
	CURTAIN_ARCHS=$(or $(ARCH),universal) ./scripts/build.sh

## Build and launch.
run: build
	open dist/Curtain.app

## Unit tests for the phases, the wake key, the options and the restore record.
test:
	swift test

## Copy the built app into /Applications.
install: build
	rm -rf /Applications/Curtain.app
	cp -R dist/Curtain.app /Applications/
	@echo "Installed. Open it from Applications, then enable Launch at Login from its menu."

## Build, sign with Developer ID, notarize, and wrap in dist/Curtain.dmg.
release:
	./scripts/release.sh

## Redraw the app icon into Resources/AppIcon.icns and docs/icon.png.
icon:
	./icon/build-icns.sh

clean:
	rm -rf .build dist icon/out
