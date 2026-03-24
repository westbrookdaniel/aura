#!/usr/bin/env bash
set -euo pipefail

APPLE_ID="westy12dan@gmail.com"
PROFILE_NAME="${LISTENER_NOTARY_PROFILE:-listener-notary}"
TEAM_ID="${LISTENER_TEAM_ID:-}"
APP_PASSWORD="${LISTENER_APP_PASSWORD:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") --team-id <id> --app-password <password> [options]

Stores an App Store Connect credential profile for notarization.

Options:
  --team-id <id>         Apple Developer Team ID
  --app-password <pass>  App-specific password for ${APPLE_ID}
  --profile <name>       Keychain profile name (default: ${PROFILE_NAME})
  --apple-id <email>     Apple ID email (default: ${APPLE_ID})
  --help                 Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --team-id)
            TEAM_ID="$2"
            shift 2
            ;;
        --app-password)
            APP_PASSWORD="$2"
            shift 2
            ;;
        --profile)
            PROFILE_NAME="$2"
            shift 2
            ;;
        --apple-id)
            APPLE_ID="$2"
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

if [[ -z "${TEAM_ID}" || -z "${APP_PASSWORD}" ]]; then
    usage >&2
    exit 1
fi

xcrun notarytool store-credentials "${PROFILE_NAME}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${TEAM_ID}" \
    --password "${APP_PASSWORD}"

echo
echo "Stored notarization profile '${PROFILE_NAME}' for ${APPLE_ID}."
