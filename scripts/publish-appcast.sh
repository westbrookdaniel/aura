#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Aura"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
UPDATES_DIR="${ROOT_DIR}/docs"
VERSION="${AURA_VERSION:-}"
SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") --version <version> [options]

Copies the built Aura archive into docs/ and regenerates Sparkle's appcast.xml.

Options:
  --version <version>         Version that matches dist/${APP_NAME}-<version>.zip
  --updates-dir <path>        Override the published updates directory (default: docs/)
  --sparkle-bin-dir <path>    Directory containing Sparkle's generate_appcast tool
  --help                      Show this help text

Environment variables:
  AURA_VERSION
  SPARKLE_BIN_DIR
EOF
}

find_generate_appcast() {
    local candidate

    if [[ -n "${SPARKLE_BIN_DIR}" ]]; then
        candidate="${SPARKLE_BIN_DIR}/generate_appcast"
        if [[ -x "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    fi

    for candidate in \
        "${ROOT_DIR}/.build/artifacts/sparkle/Sparkle/bin/generate_appcast" \
        "${ROOT_DIR}/.build/checkouts/../artifacts/sparkle/Sparkle/bin/generate_appcast"
    do
        if [[ -x "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    candidate="$(find "${ROOT_DIR}/.build" -path '*/Sparkle/bin/generate_appcast' -type f -perm -111 -print -quit 2>/dev/null || true)"
    if [[ -n "${candidate}" ]]; then
        printf '%s\n' "${candidate}"
        return 0
    fi

    return 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --updates-dir)
            UPDATES_DIR="$2"
            shift 2
            ;;
        --sparkle-bin-dir)
            SPARKLE_BIN_DIR="$2"
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
    exit 1
fi

ARCHIVE_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.zip"

if [[ ! -f "${ARCHIVE_PATH}" ]]; then
    echo "Archive not found at ${ARCHIVE_PATH}" >&2
    exit 1
fi

GENERATE_APPCAST="$(find_generate_appcast)" || {
    echo "Could not find Sparkle's generate_appcast tool. Set SPARKLE_BIN_DIR to Sparkle/bin." >&2
    exit 1
}

mkdir -p "${UPDATES_DIR}"
cp "${ARCHIVE_PATH}" "${UPDATES_DIR}/"

for extension in html md; do
    if [[ -f "${DIST_DIR}/${APP_NAME}-${VERSION}.${extension}" ]]; then
        cp "${DIST_DIR}/${APP_NAME}-${VERSION}.${extension}" "${UPDATES_DIR}/"
    fi
done

echo "Generating appcast in ${UPDATES_DIR}..."
"${GENERATE_APPCAST}" "${UPDATES_DIR}"

echo
echo "Sparkle artifacts updated in:"
echo "  ${UPDATES_DIR}"
echo
echo "Commit and push the docs/ changes after reviewing appcast.xml."
