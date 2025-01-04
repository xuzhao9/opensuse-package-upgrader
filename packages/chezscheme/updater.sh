#!/usr/bin/env bash

# =============================================
#  CHEZSCHEME SPEC UPDATER SCRIPT
# =============================================
# USAGE:
# bash updater.sh <OSC_REPO_DIR>

set -xe

if [ -z "$1" ]; then
    echo "Must provide OSC_REPO_DIR as the first argument."
    exit 1
fi
OSC_REPO_DIR="$1"; shift
PACKAGE_NAME=$(basename "${OSC_REPO_DIR}")
optspec="c"
while getopts "$optspec" optchar; do
    case $optchar in
        c) CHECK_ONLY=true
           ;;
        ?) echo "Invalid option -$optchar" ; exit 1;
    esac
done
OSC_SPEC_FILE="chezscheme.spec"
if [ ! -f "${OSC_REPO_DIR}"/"${OSC_SPEC_FILE}" ]; then
    echo "${OSC_REPO_DIR}/${OSC_SPEC_FILE} must exist to proceed."
    exit 1
fi

# Get tag_name, rpm url, and rpm_sig_url
SRC_REPO_DIR="/tmp/osc-packager/${PACKAGE_NAME}"
REL_URL="https://api.github.com/repos/cisco/ChezScheme/releases"
[[ -d "${SRC_REPO_DIR}" ]] && rm -rf "${SRC_REPO_DIR}"
mkdir -p "${SRC_REPO_DIR}"
curl -o "${SRC_REPO_DIR}"/release_list.json "${REL_URL}"
# By default, we do not package beta version
TAG_NAME=$(jq -r '.[] | select(.tag_name) | .tag_name' "${SRC_REPO_DIR}"/release_list.json | head -n 1)
# TAG_NAME must exist to proceed
if [[ -z "${TAG_NAME}" ]]; then
    echo "Unexpected empty TAG_NAME. Exit."
    exit 1
fi

echo "Getting current repo revision..."
CURRENT_TAG=$(awk '/^Version: / {match($0, /[0-9.]+/, ary);print ary[0]}' "${OSC_REPO_DIR}/${OSC_SPEC_FILE}")
if [[ "v${CURRENT_TAG}" == $TAG_NAME ]]; then
    echo "The current tag is the latest: ${TAG_NAME}. Skipping the update."
    exit 0
fi

echo "The current version does not meet the latest tag name and requires update: ${CURRENT_TAG} -> ${TAG_NAME}"
if [[ ${CHECK_ONLY:-false} == true ]]; then
    echo "Exiting as check-only script."
    exit 0
fi

# Replace the revision field
echo "Updating _service and spec file..."
pushd "${OSC_REPO_DIR}"
awk -v tag_name="${TAG_NAME}" '/^Version: / {sub(/[0-9.]+/, tag_name);}1' ${OSC_SPEC_FILE} > ${OSC_SPEC_FILE}.backup
mv ${OSC_SPEC_FILE}.backup ${OSC_SPEC_FILE}
awk -v tag_name="${TAG_NAME}" '/^\s*<param name="revision">/ {sub(/[0-9.]+/, tag_name);}1' _service > _service.backup
mv _service.backup _service
popd

echo "Remove source code repo..."
[[ -d "${SRC_REPO_DIR}" ]] && rm -rf "${SRC_REPO_DIR}"

echo "Success!"
