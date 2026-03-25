#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Aura"
DEVELOPER_NAME="Daniel Westbrook"
APPLE_ID_DEFAULT="westy12dan@gmail.com"
DEFAULT_NOTARY_PROFILE="aura-notary"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
SCRATCH_DIR="${ROOT_DIR}/.build"
BUILD_CACHE_DIR="${ROOT_DIR}/.cache/release"
CLANG_CACHE_DIR="${BUILD_CACHE_DIR}/clang"
SWIFTPM_CACHE_DIR="${BUILD_CACHE_DIR}/swiftpm"
ORG_SWIFTPM_CACHE_DIR="${BUILD_CACHE_DIR}/org.swift.swiftpm"
TMP_DIR="${BUILD_CACHE_DIR}/tmp"
DEFAULT_APP_ICON_PATH="${ROOT_DIR}/Packaging/AppIcon.icns"
APP_ICON_PREVIEW_PATH="${ROOT_DIR}/Packaging/AuraIconPreview.png"

BUNDLE_ID="${AURA_BUNDLE_ID:-com.westbrookdaniel.aura}"
VERSION="${AURA_VERSION:-0.1.1}"
SHORT_VERSION="${AURA_SHORT_VERSION:-}"
MIN_SYSTEM_VERSION="${AURA_MIN_SYSTEM_VERSION:-13.3}"
MICROPHONE_USAGE="${AURA_MICROPHONE_USAGE:-Aura needs microphone access to capture dictation audio.}"
SIGN_IDENTITY="${AURA_CODESIGN_IDENTITY:-}"
TEAM_ID="${AURA_TEAM_ID:-}"
NOTARY_PROFILE="${AURA_NOTARY_PROFILE:-${DEFAULT_NOTARY_PROFILE}}"
APP_ICON_PATH="${AURA_APP_ICON:-${DEFAULT_APP_ICON_PATH}}"
SPARKLE_FEED_URL="${AURA_SPARKLE_FEED_URL:-https://westbrookdaniel.github.io/aura/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${AURA_SPARKLE_PUBLIC_ED_KEY:-}"
SPARKLE_ENABLE_AUTOMATIC_CHECKS="${AURA_SPARKLE_ENABLE_AUTOMATIC_CHECKS:-YES}"
SPARKLE_ALLOW_AUTOMATIC_UPDATES="${AURA_SPARKLE_ALLOW_AUTOMATIC_UPDATES:-YES}"
SPARKLE_AUTOMATICALLY_UPDATE="${AURA_SPARKLE_AUTOMATICALLY_UPDATE:-YES}"
SPARKLE_SCHEDULED_CHECK_INTERVAL="${AURA_SPARKLE_SCHEDULED_CHECK_INTERVAL:-86400}"

ARCHIVE=1
NOTARIZE=0

plist_bool() {
    local normalized
    normalized="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"

    case "${normalized}" in
        YES|TRUE|1)
            printf '<true/>'
            ;;
        NO|FALSE|0)
            printf '<false/>'
            ;;
        *)
            echo "Expected YES/NO style boolean but received '$1'." >&2
            exit 1
            ;;
    esac
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

find_framework_named() {
    local framework_name="$1"
    shift

    local search_root
    local candidate

    for search_root in "$@"; do
        [[ -d "${search_root}" ]] || continue
        candidate="$(find "${search_root}" -path "*/${framework_name}.framework" -type d -print -quit 2>/dev/null || true)"
        if [[ -n "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    return 1
}

embed_linked_frameworks() {
    local binary_path="$1"
    local destination_dir="$2"
    local framework_name
    local framework_source
    local search_roots=(
        "$(dirname "${binary_path}")"
        "${SCRATCH_DIR}"
        "${ROOT_DIR}/.build"
        "${ROOT_DIR}/.build/checkouts"
        "${ROOT_DIR}/.build/artifacts"
    )

    while IFS= read -r framework_name; do
        [[ -n "${framework_name}" ]] || continue

        framework_source="$(find_framework_named "${framework_name}" "${search_roots[@]}")" || true
        if [[ -z "${framework_source:-}" ]]; then
            echo "${framework_name}.framework was linked into ${APP_NAME} but could not be found in the build products." >&2
            exit 1
        fi

        echo "Embedding ${framework_name}.framework..."
        ditto "${framework_source}" "${destination_dir}/${framework_name}.framework"
    done < <(
        otool -L "${binary_path}" |
            sed -n 's|^[[:space:]]*@rpath/\([^/]*\)\.framework/.*|\1|p' |
            sort -u
    )
}

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
  AURA_BUNDLE_ID
  AURA_VERSION
  AURA_SHORT_VERSION
  AURA_MIN_SYSTEM_VERSION
  AURA_MICROPHONE_USAGE
  AURA_CODESIGN_IDENTITY
  AURA_TEAM_ID
  AURA_NOTARY_PROFILE
  AURA_APP_ICON
  AURA_SPARKLE_FEED_URL
  AURA_SPARKLE_PUBLIC_ED_KEY
  AURA_SPARKLE_ENABLE_AUTOMATIC_CHECKS
  AURA_SPARKLE_ALLOW_AUTOMATIC_UPDATES
  AURA_SPARKLE_AUTOMATICALLY_UPDATE
  AURA_SPARKLE_SCHEDULED_CHECK_INTERVAL

Defaults:
  bundle id: ${BUNDLE_ID}
  developer: ${DEVELOPER_NAME}
  apple id: ${APPLE_ID_DEFAULT}
  notary profile: ${NOTARY_PROFILE}
  sparkle feed: ${SPARKLE_FEED_URL}
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bundle-id)
            require_option_value "$1" "${2-}"
            BUNDLE_ID="$2"
            shift 2
            ;;
        --version)
            require_option_value "$1" "${2-}"
            VERSION="$2"
            SHORT_VERSION="${SHORT_VERSION:-$2}"
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

ARCHIVE_FILENAME="${APP_NAME}-${VERSION}.zip"
ARCHIVE_PATH="${DIST_DIR}/${ARCHIVE_FILENAME}"
SPARKLE_ENABLE_AUTOMATIC_CHECKS_PLIST="$(plist_bool "${SPARKLE_ENABLE_AUTOMATIC_CHECKS}")"
SPARKLE_ALLOW_AUTOMATIC_UPDATES_PLIST="$(plist_bool "${SPARKLE_ALLOW_AUTOMATIC_UPDATES}")"
SPARKLE_AUTOMATICALLY_UPDATE_PLIST="$(plist_bool "${SPARKLE_AUTOMATICALLY_UPDATE}")"

if [[ -z "${SIGN_IDENTITY}" && -n "${TEAM_ID}" ]]; then
    SIGN_IDENTITY="Developer ID Application: ${DEVELOPER_NAME} (${TEAM_ID})"
fi

if [[ "${NOTARIZE}" -eq 1 && -z "${NOTARY_PROFILE}" ]]; then
    echo "Notarization requires --notary-profile or AURA_NOTARY_PROFILE." >&2
    exit 1
fi

if [[ "${NOTARIZE}" -eq 1 && -z "${SIGN_IDENTITY}" ]]; then
    echo "Notarization requires --sign or AURA_CODESIGN_IDENTITY." >&2
    exit 1
fi

mkdir -p "${DIST_DIR}" "${CLANG_CACHE_DIR}" "${SWIFTPM_CACHE_DIR}" "${ORG_SWIFTPM_CACHE_DIR}" "${TMP_DIR}"
rm -rf "${APP_BUNDLE}" "${ARCHIVE_PATH}"

export TMPDIR="${TMP_DIR}"
export TMP="${TMP_DIR}"
export TEMP="${TMP_DIR}"

SWIFT_BUILD_ENV=(
    "DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer"
    "CLANG_MODULE_CACHE_PATH=${CLANG_CACHE_DIR}"
    "SWIFTPM_MODULECACHE_OVERRIDE=${SWIFTPM_CACHE_DIR}"
    "HOME=${ROOT_DIR}"
)

if [[ "${APP_ICON_PATH}" == "${DEFAULT_APP_ICON_PATH}" ]]; then
    echo "Generating Aura app icon..."
    env "${SWIFT_BUILD_ENV[@]}" swift "${ROOT_DIR}/Packaging/GenerateAppIcon.swift" "${APP_ICON_PATH}"
fi

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
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${FRAMEWORKS_DIR}"

cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod 755 "${MACOS_DIR}/${APP_NAME}"
embed_linked_frameworks "${BIN_PATH}" "${FRAMEWORKS_DIR}"

INFO_TEMPLATE="${ROOT_DIR}/Packaging/Info.plist.template"
INFO_PLIST="${CONTENTS_DIR}/Info.plist"
sed \
    -e "s|__APP_NAME__|${APP_NAME}|g" \
    -e "s|__BUNDLE_ID__|${BUNDLE_ID}|g" \
    -e "s|__VERSION__|${VERSION}|g" \
    -e "s|__SHORT_VERSION__|${SHORT_VERSION}|g" \
    -e "s|__MIN_SYSTEM_VERSION__|${MIN_SYSTEM_VERSION}|g" \
    -e "s|__MICROPHONE_USAGE__|${MICROPHONE_USAGE}|g" \
    -e "s|__SPARKLE_FEED_URL__|${SPARKLE_FEED_URL}|g" \
    -e "s|__SPARKLE_PUBLIC_ED_KEY__|${SPARKLE_PUBLIC_ED_KEY}|g" \
    -e "s|__SPARKLE_ENABLE_AUTOMATIC_CHECKS__|${SPARKLE_ENABLE_AUTOMATIC_CHECKS_PLIST}|g" \
    -e "s|__SPARKLE_ALLOW_AUTOMATIC_UPDATES__|${SPARKLE_ALLOW_AUTOMATIC_UPDATES_PLIST}|g" \
    -e "s|__SPARKLE_AUTOMATICALLY_UPDATE__|${SPARKLE_AUTOMATICALLY_UPDATE_PLIST}|g" \
    -e "s|__SPARKLE_SCHEDULED_CHECK_INTERVAL__|${SPARKLE_SCHEDULED_CHECK_INTERVAL}|g" \
    "${INFO_TEMPLATE}" > "${INFO_PLIST}"

if [[ -f "${APP_ICON_PATH}" ]]; then
    cp "${APP_ICON_PATH}" "${RESOURCES_DIR}/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${INFO_PLIST}" >/dev/null 2>&1 || \
        /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "${INFO_PLIST}" >/dev/null
fi

if [[ -f "${APP_ICON_PREVIEW_PATH}" ]]; then
    env "${SWIFT_BUILD_ENV[@]}" swift "${ROOT_DIR}/Packaging/ApplyBundleIcon.swift" "${APP_ICON_PREVIEW_PATH}" "${APP_BUNDLE}"
fi

if [[ -z "${SPARKLE_PUBLIC_ED_KEY}" ]]; then
    echo "Warning: AURA_SPARKLE_PUBLIC_ED_KEY is not set, so automatic updates will be unavailable in this build." >&2
fi

if [[ -n "${SIGN_IDENTITY}" ]]; then
    echo "Signing ${APP_BUNDLE}..."
    codesign --force --deep --options runtime --sign "${SIGN_IDENTITY}" "${APP_BUNDLE}"
    codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"
else
    echo "Skipping code signing. Set AURA_CODESIGN_IDENTITY or pass --sign to sign the app."
fi

if [[ "${ARCHIVE}" -eq 1 ]]; then
    echo "Creating zip archive..."
    ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ARCHIVE_PATH}"
fi

if [[ "${NOTARIZE}" -eq 1 ]]; then
    echo "Submitting ${ARCHIVE_FILENAME} for notarization..."
    xcrun notarytool submit "${ARCHIVE_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
    echo "Stapling notarization ticket..."
    xcrun stapler staple "${APP_BUNDLE}"
    echo "Rebuilding zip archive with stapled app..."
    rm -f "${ARCHIVE_PATH}"
    ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ARCHIVE_PATH}"
fi

echo
echo "App bundle ready at:"
echo "  ${APP_BUNDLE}"

if [[ "${ARCHIVE}" -eq 1 ]]; then
    echo "Archive ready at:"
    echo "  ${ARCHIVE_PATH}"
fi
