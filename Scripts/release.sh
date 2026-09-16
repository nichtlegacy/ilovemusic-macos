#!/usr/bin/env bash
# Cuts a public release: build, DMG, GitHub release, Sparkle appcast.
#
#   Scripts/release.sh --version 0.2.0 [--notes .github/release-notes/0.2.0.md] [--dry-run]
#
# Omitting --version reuses the version already in the VERSION file, which is
# how you retry a release that failed halfway through.
#
# Requirements: gh (authenticated), Sparkle's private EdDSA key in the login
# keychain, a clean worktree on the release branch.
set -euo pipefail

cd "$(dirname "$0")/.."

NAME="ILoveMusic"
REPO="nichtlegacy/ilovemusic_mac"
RELEASE_BRANCH="main"
# `origin` stays on the private Forgejo mirror; releases go to the public GitHub remote.
RELEASE_REMOTE="github"
DIST_DIR="dist"

NEW_VERSION=""
NOTES_PATH=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --version) NEW_VERSION="${2-}"; shift 2 ;;
    --notes) NOTES_PATH="${2-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "error: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

# --- Preflight -------------------------------------------------------------

command -v gh >/dev/null || { echo "error: gh not installed" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "error: gh is not authenticated, run 'gh auth login'" >&2; exit 1; }
git remote get-url "$RELEASE_REMOTE" >/dev/null 2>&1 || {
  echo "error: no git remote named '${RELEASE_REMOTE}'" >&2
  echo "hint: git remote add ${RELEASE_REMOTE} https://github.com/${REPO}.git" >&2
  exit 1
}

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$BRANCH" != "$RELEASE_BRANCH" ]; then
  echo "error: on branch '${BRANCH}', releases are cut from '${RELEASE_BRANCH}'" >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "error: worktree is dirty, commit or stash first" >&2
  exit 1
fi

if [ -n "$NEW_VERSION" ]; then
  if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: --version must be X.Y.Z, got '${NEW_VERSION}'" >&2
    exit 1
  fi
  if [ "$NEW_VERSION" != "$(tr -d '[:space:]' < VERSION)" ]; then
    echo "==> Bumping VERSION to ${NEW_VERSION}"
    run bash -c "printf '%s\n' '${NEW_VERSION}' > VERSION"
    run git add VERSION
    run git commit -m "chore(release): v${NEW_VERSION}"
  fi
fi

# --dry-run never writes VERSION, so take the requested version directly rather
# than re-reading a file that still holds the old one.
VERSION="${NEW_VERSION:-$(tr -d '[:space:]' < VERSION)}"
TAG="v${VERSION}"
DMG_PATH="${DIST_DIR}/${NAME}-${VERSION}.dmg"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${NAME}-${VERSION}.dmg"

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "error: tag ${TAG} already exists, bump the version first" >&2
  exit 1
fi

if [ -z "$NOTES_PATH" ] && [ -f ".github/release-notes/${VERSION}.md" ]; then
  NOTES_PATH=".github/release-notes/${VERSION}.md"
fi

echo
echo "About to publish ${NAME} ${VERSION} to https://github.com/${REPO}"
echo "  tag:       ${TAG}"
echo "  asset:     ${DMG_PATH}"
echo "  notes:     ${NOTES_PATH:-<none>}"
echo "  appcast:   appcast.xml (pushed to ${RELEASE_BRANCH})"
echo
if [ "$DRY_RUN" -eq 0 ]; then
  read -r -p "Publish? This creates a public GitHub release. [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "aborted"; exit 1 ;;
  esac
fi

# --- Build -----------------------------------------------------------------

run ./Scripts/build-app.sh
run ./Scripts/package-dmg.sh

if [ "$DRY_RUN" -eq 0 ]; then
  BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' ".build/${NAME}.app/Contents/Info.plist")"
else
  BUILD_NUMBER="$(git rev-list --count HEAD)"
fi

# --- Publish ---------------------------------------------------------------

echo "==> Tagging ${TAG}"
run git tag -a "$TAG" -m "${NAME} ${VERSION}"
run git push "$RELEASE_REMOTE" "$RELEASE_BRANCH"
run git push "$RELEASE_REMOTE" "$TAG"

echo "==> Creating GitHub release"
if [ -n "$NOTES_PATH" ]; then
  run gh release create "$TAG" "$DMG_PATH" \
    --repo "$REPO" --title "${NAME} ${VERSION}" --notes-file "$NOTES_PATH"
else
  run gh release create "$TAG" "$DMG_PATH" \
    --repo "$REPO" --title "${NAME} ${VERSION}" --generate-notes
fi

echo "==> Updating appcast"
APPCAST_ARGS=(
  --dmg "$DMG_PATH"
  --version "$VERSION"
  --build "$BUILD_NUMBER"
  --url "$DOWNLOAD_URL"
)
if [ -n "$NOTES_PATH" ]; then
  APPCAST_ARGS+=(--notes "$NOTES_PATH")
fi
run python3 Scripts/update-appcast.py "${APPCAST_ARGS[@]}"
run git add appcast.xml
run git commit -m "chore(release): appcast for v${VERSION}"
run git push "$RELEASE_REMOTE" "$RELEASE_BRANCH"

echo
echo "Released ${NAME} ${VERSION} (build ${BUILD_NUMBER})"
echo "  ${DOWNLOAD_URL}"
echo
echo "Verify the update feed reaches users:"
echo "  curl -sSf https://raw.githubusercontent.com/${REPO}/${RELEASE_BRANCH}/appcast.xml | head -40"
