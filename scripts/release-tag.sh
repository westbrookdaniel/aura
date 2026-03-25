#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Aura"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_UPDATES_DIR="${ROOT_DIR}/docs"

VERSION="${AURA_VERSION:-}"
SHORT_VERSION="${AURA_SHORT_VERSION:-}"
SIGN_IDENTITY="${AURA_CODESIGN_IDENTITY:-}"
TEAM_ID="${AURA_TEAM_ID:-}"
NOTARY_PROFILE="${AURA_NOTARY_PROFILE:-}"
UPDATES_DIR="${DEFAULT_UPDATES_DIR}"
SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:-}"
TAG_PREFIX="${AURA_RELEASE_TAG_PREFIX:-v}"
COMMIT_MESSAGE=""
TAG_MESSAGE=""
NOTARIZE=0

usage() {
    cat <<EOF
Usage: $(basename "$0") --version <version> [options]

Builds a release archive, publishes Sparkle artifacts into docs/, commits the
release files, and creates an annotated git tag.

Options:
  --version <version>         Release version (required)
  --short-version <version>   CFBundleShortVersionString to embed
  --sign <identity>           Code signing identity passed to build-app.sh
  --team-id <id>              Apple Developer Team ID passed to build-app.sh
  --notary-profile <name>     notarytool keychain profile passed to build-app.sh
  --notarize                  Notarize and staple the app before publishing
  --updates-dir <path>        Directory where appcast artifacts are published
  --sparkle-bin-dir <path>    Directory containing Sparkle's generate_appcast
  --tag-prefix <prefix>       Prefix for the git tag (default: ${TAG_PREFIX})
  --commit-message <message>  Override the git commit message
  --tag-message <message>     Override the annotated git tag message
  --help                      Show this help text

Environment variables:
  AURA_VERSION
  AURA_SHORT_VERSION
  AURA_CODESIGN_IDENTITY
  AURA_TEAM_ID
  AURA_NOTARY_PROFILE
  AURA_RELEASE_TAG_PREFIX
  SPARKLE_BIN_DIR
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

path_is_allowed() {
    local candidate="$1"
    shift

    local allowed_path
    for allowed_path in "$@"; do
        if [[ "${candidate}" == "${allowed_path}" ]]; then
            return 0
        fi
    done

    return 1
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
        --notary-profile)
            require_option_value "$1" "${2-}"
            NOTARY_PROFILE="$2"
            shift 2
            ;;
        --notarize)
            NOTARIZE=1
            shift
            ;;
        --updates-dir)
            require_option_value "$1" "${2-}"
            UPDATES_DIR="$2"
            shift 2
            ;;
        --sparkle-bin-dir)
            require_option_value "$1" "${2-}"
            SPARKLE_BIN_DIR="$2"
            shift 2
            ;;
        --tag-prefix)
            require_option_value "$1" "${2-}"
            TAG_PREFIX="$2"
            shift 2
            ;;
        --commit-message)
            require_option_value "$1" "${2-}"
            COMMIT_MESSAGE="$2"
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
if [[ -z "${COMMIT_MESSAGE}" ]]; then
    COMMIT_MESSAGE="Release ${TAG_NAME}"
fi
if [[ -z "${TAG_MESSAGE}" ]]; then
    TAG_MESSAGE="${COMMIT_MESSAGE}"
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

if [[ -n "${NOTARY_PROFILE}" ]]; then
    BUILD_CMD+=("--notary-profile" "${NOTARY_PROFILE}")
fi

if [[ "${NOTARIZE}" -eq 1 ]]; then
    BUILD_CMD+=("--notarize")
fi

echo "Building ${APP_NAME} ${VERSION}..."
"${BUILD_CMD[@]}"

PUBLISH_CMD=(
    "${ROOT_DIR}/scripts/publish-appcast.sh"
    "--version" "${VERSION}"
    "--updates-dir" "${UPDATES_DIR}"
)

if [[ -n "${SPARKLE_BIN_DIR}" ]]; then
    PUBLISH_CMD+=("--sparkle-bin-dir" "${SPARKLE_BIN_DIR}")
fi

echo "Publishing Sparkle artifacts..."
"${PUBLISH_CMD[@]}"

RELEASE_PATHS=(
    "${UPDATES_DIR}/appcast.xml"
    "${UPDATES_DIR}/${APP_NAME}-${VERSION}.zip"
)

for extension in html md; do
    if [[ -f "${UPDATES_DIR}/${APP_NAME}-${VERSION}.${extension}" ]]; then
        RELEASE_PATHS+=("${UPDATES_DIR}/${APP_NAME}-${VERSION}.${extension}")
    fi
done

RELEASE_GIT_PATHS=()
for release_path in "${RELEASE_PATHS[@]}"; do
    if [[ "${release_path}" != "${ROOT_DIR}/"* ]]; then
        echo "Release path ${release_path} is outside the git repository." >&2
        exit 1
    fi

    RELEASE_GIT_PATHS+=("${release_path#"${ROOT_DIR}/"}")
done

mapfile -t CHANGED_TRACKED_PATHS < <(git -C "${ROOT_DIR}" diff --name-only)
for changed_path in "${CHANGED_TRACKED_PATHS[@]}"; do
    if ! path_is_allowed "${changed_path}" "${RELEASE_GIT_PATHS[@]}"; then
        echo "Build produced an unexpected tracked change outside release artifacts: ${changed_path}" >&2
        echo "Review the repository state before creating a release commit." >&2
        exit 1
    fi
done

echo "Creating release commit..."
git -C "${ROOT_DIR}" add -- "${RELEASE_GIT_PATHS[@]}"

if git -C "${ROOT_DIR}" diff --cached --quiet; then
    echo "No release artifact changes were staged; aborting before commit/tag." >&2
    exit 1
fi

git -C "${ROOT_DIR}" commit -m "${COMMIT_MESSAGE}"
RELEASE_COMMIT="$(git -C "${ROOT_DIR}" rev-parse HEAD)"

echo "Creating annotated tag ${TAG_NAME} on ${RELEASE_COMMIT}..."
git -C "${ROOT_DIR}" tag -a "${TAG_NAME}" "${RELEASE_COMMIT}" -m "${TAG_MESSAGE}"

echo
echo "Release commit and tag created successfully:"
echo "  commit: ${RELEASE_COMMIT}"
echo "  commit message: ${COMMIT_MESSAGE}"
echo "  tag: ${TAG_NAME}"
echo
echo "Next step:"
echo "  git push origin HEAD --follow-tags"
