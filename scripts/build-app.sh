#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Listener"
DEVELOPER_NAME="Daniel Westbrook"
APPLE_ID_DEFAULT="westy12dan@gmail.com"
DEFAULT_NOTARY_PROFILE="listener-notary"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
SCRATCH_DIR="${ROOT_DIR}/.build-release"
BUILD_CACHE_DIR="${ROOT_DIR}/.cache/release"
CLANG_CACHE_DIR="${BUILD_CACHE_DIR}/clang"
SWIFTPM_CACHE_DIR="${BUILD_CACHE_DIR}/swiftpm"
ORG_SWIFTPM_CACHE_DIR="${BUILD_CACHE_DIR}/org.swift.swiftpm"
TMP_DIR="${BUILD_CACHE_DIR}/tmp"

BUNDLE_ID="${LISTENER_BUNDLE_ID:-com.westbrookdaniel.listener}"
VERSION="${LISTENER_VERSION:-0.1.0}"
SHORT_VERSION="${LISTENER_SHORT_VERSION:-}"
MIN_SYSTEM_VERSION="${LISTENER_MIN_SYSTEM_VERSION:-13.0}"
MICROPHONE_USAGE="${LISTENER_MICROPHONE_USAGE:-Listener needs microphone access to capture dictation audio.}"
SIGN_IDENTITY="${LISTENER_CODESIGN_IDENTITY:-}"
TEAM_ID="${LISTENER_TEAM_ID:-}"
NOTARY_PROFILE="${LISTENER_NOTARY_PROFILE:-${DEFAULT_NOTARY_PROFILE}}"
APP_ICON_PATH="${LISTENER_APP_ICON:-${ROOT_DIR}/Packaging/AppIcon.icns}"

ARCHIVE=1
NOTARIZE=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Builds a release .app bundle for ${APP_NAME} from this Swift package.
Running with no arguments builds version ${VERSION} and creates both the app bundle and zip.

Options:
  --bundle-id <id>          CFBundleIdentifier to embed in the app bundle
  --version <version>       CFBundleVersion
  --short-version <version> CFBundleShortVersionString
  --sign <identity>         Code signing identity for codesign
  --team-id <id>            Apple Developer Team ID
  --notary-profile <name>   notarytool keychain profile to use for notarization
  --archive                 Create a zip archive in dist/ (default)
  --notarize                Submit the app zip for notarization and staple the result
  --help                    Show this help text

Environment variables:
  LISTENER_BUNDLE_ID
  LISTENER_VERSION
  LISTENER_SHORT_VERSION
  LISTENER_MIN_SYSTEM_VERSION
  LISTENER_MICROPHONE_USAGE
  LISTENER_CODESIGN_IDENTITY
  LISTENER_TEAM_ID
  LISTENER_NOTARY_PROFILE
  LISTENER_APP_ICON

Defaults:
  bundle id: ${BUNDLE_ID}
  developer: ${DEVELOPER_NAME}
  apple id: ${APPLE_ID_DEFAULT}
  notary profile: ${NOTARY_PROFILE}
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bundle-id)
            BUNDLE_ID="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            SHORT_VERSION="${SHORT_VERSION:-$2}"
            shift 2
            ;;
        --short-version)
            SHORT_VERSION="$2"
            shift 2
            ;;
        --sign)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        --team-id)
            TEAM_ID="$2"
            shift 2
            ;;
        --notary-profile)
            NOTARY_PROFILE="$2"
            shift 2
            ;;
        --archive)
            ARCHIVE=1
            shift
            ;;
        --notarize)
            NOTARIZE=1
            ARCHIVE=1
            shift
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

if [[ -z "${SHORT_VERSION}" ]]; then
    SHORT_VERSION="${VERSION}"
fi

if [[ -z "${SIGN_IDENTITY}" && -n "${TEAM_ID}" ]]; then
    SIGN_IDENTITY="Developer ID Application: ${DEVELOPER_NAME} (${TEAM_ID})"
fi

if [[ "${NOTARIZE}" -eq 1 && -z "${NOTARY_PROFILE}" ]]; then
    echo "Notarization requires --notary-profile or LISTENER_NOTARY_PROFILE." >&2
    exit 1
fi

if [[ "${NOTARIZE}" -eq 1 && -z "${SIGN_IDENTITY}" ]]; then
    echo "Notarization requires --sign or LISTENER_CODESIGN_IDENTITY." >&2
    exit 1
fi

mkdir -p "${DIST_DIR}" "${CLANG_CACHE_DIR}" "${SWIFTPM_CACHE_DIR}" "${ORG_SWIFTPM_CACHE_DIR}" "${TMP_DIR}"
rm -rf "${APP_BUNDLE}" "${DIST_DIR}/${APP_NAME}.zip"

export TMPDIR="${TMP_DIR}"
export TMP="${TMP_DIR}"
export TEMP="${TMP_DIR}"

SWIFT_BUILD_ENV=(
    "DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer"
    "CLANG_MODULE_CACHE_PATH=${CLANG_CACHE_DIR}"
    "SWIFTPM_MODULECACHE_OVERRIDE=${SWIFTPM_CACHE_DIR}"
    "HOME=${ROOT_DIR}"
)

echo "Building ${APP_NAME} in release mode..."
env "${SWIFT_BUILD_ENV[@]}" swift build --disable-sandbox --scratch-path "${SCRATCH_DIR}" -c release --product "${APP_NAME}"

BIN_PATH="$(env "${SWIFT_BUILD_ENV[@]}" swift build --disable-sandbox --scratch-path "${SCRATCH_DIR}" -c release --show-bin-path)/${APP_NAME}"
if [[ ! -x "${BIN_PATH}" ]]; then
    echo "Built executable not found at ${BIN_PATH}" >&2
    exit 1
fi

CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod 755 "${MACOS_DIR}/${APP_NAME}"

INFO_TEMPLATE="${ROOT_DIR}/Packaging/Info.plist.template"
INFO_PLIST="${CONTENTS_DIR}/Info.plist"
sed \
    -e "s|__APP_NAME__|${APP_NAME}|g" \
    -e "s|__BUNDLE_ID__|${BUNDLE_ID}|g" \
    -e "s|__VERSION__|${VERSION}|g" \
    -e "s|__SHORT_VERSION__|${SHORT_VERSION}|g" \
    -e "s|__MIN_SYSTEM_VERSION__|${MIN_SYSTEM_VERSION}|g" \
    -e "s|__MICROPHONE_USAGE__|${MICROPHONE_USAGE}|g" \
    "${INFO_TEMPLATE}" > "${INFO_PLIST}"

if [[ -f "${APP_ICON_PATH}" ]]; then
    cp "${APP_ICON_PATH}" "${RESOURCES_DIR}/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${INFO_PLIST}" >/dev/null 2>&1 || \
        /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "${INFO_PLIST}" >/dev/null
fi

if [[ -n "${SIGN_IDENTITY}" ]]; then
    echo "Signing ${APP_BUNDLE}..."
    codesign --force --deep --options runtime --sign "${SIGN_IDENTITY}" "${APP_BUNDLE}"
    codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"
else
    echo "Skipping code signing. Set LISTENER_CODESIGN_IDENTITY or pass --sign to sign the app."
fi

if [[ "${ARCHIVE}" -eq 1 ]]; then
    echo "Creating zip archive..."
    ditto -c -k --keepParent "${APP_BUNDLE}" "${DIST_DIR}/${APP_NAME}.zip"
fi

if [[ "${NOTARIZE}" -eq 1 ]]; then
    echo "Submitting ${APP_NAME}.zip for notarization..."
    xcrun notarytool submit "${DIST_DIR}/${APP_NAME}.zip" --keychain-profile "${NOTARY_PROFILE}" --wait
    echo "Stapling notarization ticket..."
    xcrun stapler staple "${APP_BUNDLE}"
    echo "Rebuilding zip archive with stapled app..."
    rm -f "${DIST_DIR}/${APP_NAME}.zip"
    ditto -c -k --keepParent "${APP_BUNDLE}" "${DIST_DIR}/${APP_NAME}.zip"
fi

echo
echo "App bundle ready at:"
echo "  ${APP_BUNDLE}"

if [[ "${ARCHIVE}" -eq 1 ]]; then
    echo "Archive ready at:"
    echo "  ${DIST_DIR}/${APP_NAME}.zip"
fi
