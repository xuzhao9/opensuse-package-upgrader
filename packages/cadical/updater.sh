#!/usr/bin/env bash

# Usage: bash updater.sh <OSC_REPO_DIR> [-c]

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/obs_submit_update.sh"

if [[ -z "${1:-}" ]]; then
    echo "Must provide OSC_REPO_DIR as the first argument." >&2
    exit 1
fi
OSC_REPO_DIR=$1
shift

CHECK_ONLY=false
while getopts ":c" opt; do
    case "$opt" in
        c) CHECK_ONLY=true ;;
        *) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    esac
done

SPEC_FILE="${OSC_REPO_DIR}/cadical.spec"
SERVICE_FILE="${OSC_REPO_DIR}/_service"
for file in "$SPEC_FILE" "$SERVICE_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "$file must exist to proceed." >&2
        exit 1
    fi
done

TAG_NAME=$(curl -fsSL 'https://api.github.com/repos/arminbiere/cadical/releases/latest' | jq -er '.tag_name')
if [[ ! "$TAG_NAME" =~ ^rel-[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Unexpected CaDiCaL release tag: $TAG_NAME" >&2
    exit 1
fi
LATEST_VERSION=${TAG_NAME#rel-}
CURRENT_VERSION=$(sed -nE 's/^[[:space:]]*Version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*$/\1/p' "$SPEC_FILE")
if [[ -z "$CURRENT_VERSION" ]]; then
    echo "Could not read the current version from $SPEC_FILE" >&2
    exit 1
fi

if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    echo "cadical is already at $LATEST_VERSION."
    exit 0
fi

echo "cadical: $CURRENT_VERSION -> $LATEST_VERSION"
if [[ "$CHECK_ONLY" == true ]]; then
    mkdir -p /tmp/osc-packager
    jq -n --arg name cadical --arg cv "$CURRENT_VERSION" --arg lv "$TAG_NAME" \
        '{name: $name, current_version: $cv, latest_version: $lv}' \
        > /tmp/osc-packager/cadical.json
    exit 0
fi

obs_prepare_branch cadical
SPEC_FILE="${OBS_BRANCH_DIR}/cadical.spec"
SERVICE_FILE="${OBS_BRANCH_DIR}/_service"
if ! grep -Eq '<param name="revision">rel-[0-9]+\.[0-9]+\.[0-9]+</param>' "$SERVICE_FILE"; then
    echo "Could not find a CaDiCaL release revision in $SERVICE_FILE" >&2
    exit 1
fi

sed -i -E "s/^([[:space:]]*Version:[[:space:]]*)[0-9]+\.[0-9]+\.[0-9]+/\1${LATEST_VERSION}/" "$SPEC_FILE"
sed -i -E "s#(<param name=\"revision\">)rel-[0-9]+\.[0-9]+\.[0-9]+(</param>)#\1${TAG_NAME}\2#" "$SERVICE_FILE"
obs_finish_update cadical "$LATEST_VERSION"
