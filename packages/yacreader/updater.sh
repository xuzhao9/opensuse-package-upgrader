#!/usr/bin/env bash

# =============================================
#  YACREADER SPEC UPDATER SCRIPT
# =============================================
# USAGE:
# bash updater.sh <OSC_REPO_DIR>

set -xe

if [ -z "$1" ]; then
    echo "Must provide OSC_REPO_DIR as the first argument."
    exit 1
fi
OSC_REPO_DIR=$1; shift
optspec="c"
while getopts "$optspec" optchar; do
    case $optchar in
        c) CHECK_ONLY=true
           ;;
        ?) echo "Invalid option -$optchar" ; exit 1;
    esac
done

OSC_SPEC_FILE="yacreader.spec"
REPO_URL="https://api.github.com/repos/YACReader/yacreader/releases"

# Argument check
if [ ! -f "${OSC_REPO_DIR}"/"${OSC_SPEC_FILE}" ]; then
    echo "${OSC_REPO_DIR}/${OSC_SPEC_FILE} must exist to proceed."
    exit 1
fi

# Get tag_name, rpm url, and rpm_sig_url
SRC_REPO_DIR="/tmp/${USER}/osc-packager"
[[ -d "${SRC_REPO_DIR}" ]] && rm -rf "${SRC_REPO_DIR}"
mkdir -p "${SRC_REPO_DIR}"
curl -o "${SRC_REPO_DIR}"/release_list.json "${REPO_URL}"
# By default, we do not package beta version
TAG_NAME=$(jq -r '.[] | .tag_name' "${SRC_REPO_DIR}"/release_list.json | head -n 1)
if [[ -z "${TAG_NAME}" ]]; then
    echo "Unexpected empty TAG_NAME. Exit."
    exit 1
fi

echo "Getting current repo revision..."
CURRENT_TAG=$(pushd ${OSC_REPO_DIR}; awk '/^Version: / {match($0, /[0-9.]+/, ary);print ary[0]}' ${OSC_SPEC_FILE})
if [[ "${CURRENT_TAG}" == $TAG_NAME ]]; then
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
