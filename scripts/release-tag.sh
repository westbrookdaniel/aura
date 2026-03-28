#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Aura"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERSION="${AURA_VERSION:-}"
SHORT_VERSION="${AURA_SHORT_VERSION:-}"
SIGN_IDENTITY="${AURA_CODESIGN_IDENTITY:-}"
TEAM_ID="${AURA_TEAM_ID:-}"
TAG_PREFIX="${AURA_RELEASE_TAG_PREFIX:-v}"
TAG_MESSAGE=""

usage() {
    cat <<EOF
Usage: $(basename "$0") --version <version> [options]

Builds a release archive in dist/ and creates an annotated git tag for the
current commit.

Options:
  --version <version>         Release version (required)
  --short-version <version>   CFBundleShortVersionString to embed
  --sign <identity>           Code signing identity passed to build-app.sh
  --team-id <id>              Apple Developer Team ID passed to build-app.sh
  --tag-prefix <prefix>       Prefix for the git tag (default: ${TAG_PREFIX})
  --tag-message <message>     Override the annotated git tag message
  --help                      Show this help text

Environment variables:
  AURA_VERSION
  AURA_SHORT_VERSION
  AURA_CODESIGN_IDENTITY
  AURA_TEAM_ID
  AURA_RELEASE_TAG_PREFIX
EOF
}

require_option_value() {
    local option_name="$1"
    local option_value="${2-}"

    if [[ -z "${option_value}" || "${option_value}" == --* ]]; then
        echo "Option ${option_name} requires a value." >&2
        usage >&2
        exit 1
    fi
}

ensure_clean_worktree() {
    if [[ -n "$(git -C "${ROOT_DIR}" status --porcelain)" ]]; then
        echo "Refusing to create a release from a dirty git worktree." >&2
        echo "Commit or stash your changes, then rerun this script." >&2
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            require_option_value "$1" "${2-}"
            VERSION="$2"
            shift 2
            ;;
        --short-version)
            require_option_value "$1" "${2-}"
            SHORT_VERSION="$2"
            shift 2
            ;;
        --sign)
            require_option_value "$1" "${2-}"
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        --team-id)
            require_option_value "$1" "${2-}"
            TEAM_ID="$2"
            shift 2
            ;;
        --tag-prefix)
            require_option_value "$1" "${2-}"
            TAG_PREFIX="$2"
            shift 2
            ;;
        --tag-message)
            require_option_value "$1" "${2-}"
            TAG_MESSAGE="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "${VERSION}" ]]; then
    echo "A version is required. Pass --version or set AURA_VERSION." >&2
    usage >&2
    exit 1
fi

if [[ -z "${SHORT_VERSION}" ]]; then
    SHORT_VERSION="${VERSION}"
fi

TAG_NAME="${TAG_PREFIX}${VERSION}"
if [[ -z "${TAG_MESSAGE}" ]]; then
    TAG_MESSAGE="Release ${TAG_NAME}"
fi

if [[ ! -d "${ROOT_DIR}/.git" ]]; then
    echo "This script must be run from inside the Aura git repository." >&2
    exit 1
fi

ensure_clean_worktree

if git -C "${ROOT_DIR}" rev-parse --verify --quiet "refs/tags/${TAG_NAME}" >/dev/null; then
    echo "Git tag ${TAG_NAME} already exists." >&2
    exit 1
fi

echo "Running tests..."
swift test --package-path "${ROOT_DIR}"

BUILD_CMD=(
    "${ROOT_DIR}/scripts/build-app.sh"
    "--version" "${VERSION}"
    "--short-version" "${SHORT_VERSION}"
)

if [[ -n "${SIGN_IDENTITY}" ]]; then
    BUILD_CMD+=("--sign" "${SIGN_IDENTITY}")
fi

if [[ -n "${TEAM_ID}" ]]; then
    BUILD_CMD+=("--team-id" "${TEAM_ID}")
fi

echo "Building ${APP_NAME} ${VERSION}..."
"${BUILD_CMD[@]}"

if [[ -n "$(git -C "${ROOT_DIR}" status --porcelain)" ]]; then
    echo "Build produced a dirty worktree. Review the generated changes before tagging a release." >&2
    exit 1
fi

RELEASE_COMMIT="$(git -C "${ROOT_DIR}" rev-parse HEAD)"

echo "Creating annotated tag ${TAG_NAME} on ${RELEASE_COMMIT}..."
git -C "${ROOT_DIR}" tag -a "${TAG_NAME}" "${RELEASE_COMMIT}" -m "${TAG_MESSAGE}"

echo
echo "Release tag created successfully:"
echo "  archive: ${ROOT_DIR}/dist/${APP_NAME}-${VERSION}.zip"
echo "  commit: ${RELEASE_COMMIT}"
echo "  tag: ${TAG_NAME}"
echo
echo "Next step:"
echo "  git push origin ${TAG_NAME}"
