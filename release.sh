#!/usr/bin/env bash
# Publishes a release from this Mac, then lets CI replace it.
#
#   ./release.sh 0.7.0
#
# Checks that main is clean and pushed, runs the tests, builds the DMG and PKG
# for this Mac, tags vX.Y.Z, pushes the tag, and publishes the release with
# these files straight away. The tag also starts the Release workflow, which
# builds the Apple silicon + Intel versions and replaces these files when it
# finishes (it can wait a long time for a GitHub macOS runner).
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?usage: ./release.sh X.Y.Z}"
TAG="v$VERSION"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Version must look like 1.2.3" >&2; exit 1; }

[[ "$(git branch --show-current)" == "main" ]] || { echo "Switch to main first." >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Commit or stash your changes first." >&2; exit 1; }
git fetch --quiet origin main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || { echo "main differs from origin/main; push or pull first." >&2; exit 1; }
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then echo "$TAG already exists." >&2; exit 1; fi
command -v gh >/dev/null || { echo "Needs the GitHub CLI (gh)." >&2; exit 1; }

if ! xcode-select -p | grep -q "Xcode" && [[ -z "${SDKROOT:-}" ]] && [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi

echo "==> Testing"
# Swift Testing only (the Command Line Tools have no XCTest), in its own build
# folder. Without Xcode the compiler sometimes misses Swift Testing's macro
# plugin, so point it there.
TEST_ARGS=(--disable-xctest --scratch-path .build/tests)
PLUGINS=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
if ! xcode-select -p | grep -q "Xcode" && [[ -d "$PLUGINS" ]]; then
  TEST_ARGS+=(-Xswiftc -plugin-path -Xswiftc "$PLUGINS")
fi
swift test "${TEST_ARGS[@]}"

./build.sh "$VERSION"
(cd dist && shasum -a 256 "TiempoPomo-$VERSION.dmg" "TiempoPomo-$VERSION.pkg" > SHA256SUMS.txt)

echo "==> Tagging $TAG"
git tag -a "$TAG" -m "Tiempo Pomo $VERSION"
git push origin "$TAG"

echo "==> Publishing this Mac's build (CI replaces it with the universal one)"
gh release create "$TAG" "dist/TiempoPomo-$VERSION.dmg" "dist/TiempoPomo-$VERSION.pkg" dist/SHA256SUMS.txt \
  --verify-tag --title "Tiempo Pomo $VERSION" --notes-file .github/release-notes.md

echo "Done: $(gh release view "$TAG" --json url -q .url)"
