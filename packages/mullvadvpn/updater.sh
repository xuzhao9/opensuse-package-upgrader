#!/usr/bin/env bash

# =============================================
#  MULLVAD-VPN SPEC UPDATER SCRIPT
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
OSC_SPEC_FILE="mullvadvpn.spec"
REPO_URL="https://api.github.com/repos/mullvad/mullvadvpn-app/releases"
ARCH="x86_64"

# Check that ${OSC_REPO_DIR}/mullvadvpn.spec exists
if [ ! -f "${OSC_REPO_DIR}"/mullvadvpn.spec ]; then
    echo "${OSC_REPO_DIR}/mullvadvpn.spec must exist to proceed."
    exit 1
fi

# Get tag_name, rpm url, and rpm_sig_url
SRC_REPO_DIR="/tmp/osc-packager/${PACKAGE_NAME}"
[[ -d "${SRC_REPO_DIR}" ]] && rm -rf "${SRC_REPO_DIR}"
mkdir -p "${SRC_REPO_DIR}"
curl -o "${SRC_REPO_DIR}"/release_list.json "${REPO_URL}"
# By default, we do not package beta version
TAG_NAMES=$(jq -r '.[] | select(.tag_name | contains("beta") or contains("android") | not) | .tag_name' "${SRC_REPO_DIR}"/release_list.json)
readarray -t TAG_ARRAY <<< "${TAG_NAMES}"
if (( ${#TAG_ARRAY[@]} == 0 )); then
    echo "Error: TAG_ARRAY is empty."
    exit 1
fi

RPM_URL=""
for tag in "${TAG_ARRAY[@]}"; do
    RPM_URL=$(jq -r --arg TAG_NAME "${tag}" --arg ARCH "${ARCH}" '.[] | select(.tag_name == $TAG_NAME) | .assets[] | select(.browser_download_url | endswith($ARCH + ".rpm")) | .browser_download_url' "${SRC_REPO_DIR}"/release_list.json)
    if [[ -n "${RPM_URL}" ]]; then
        break
    fi
done

if [[ -z "${RPM_URL}" ]]; then
    echo "Unexpected empty RPM_URL. Exit."
    exit 1
fi
echo "Get RPM URL: ${RPM_URL}"
RPM_FILE_NAME=$(basename ${RPM_URL})

echo "Getting current repo revision..."
CURRENT_TAG=$(awk '/^\s*%define ver/ {match($0, /[0-9.]+/, ary);print ary[0]}' ${OSC_REPO_DIR}/${OSC_SPEC_FILE})
if [[ $CURRENT_TAG == $TAG_NAME ]]; then
    echo "The current tag is the latest: ${TAG_NAME}. Skipping the update."
    exit 0
fi

echo "The current version does not meet the latest tag name and requires update: ${CURRENT_TAG} -> ${TAG_NAME}"
if [[ ${CHECK_ONLY:-false} == true ]]; then
    echo "Exiting as check-only script. Writing results to /tmp/osc-packager/mullvadvpn.json"
    jq -n --arg name ${PACKAGE_NAME} \
       --arg cv ${CURRENT_TAG} \
       --arg lv ${TAG_NAME} \
       '{ name: $ARGS.name, current_version: $ARGS.cv, latest_version: $ARGS.lv}' \
       > /tmp/osc-packager/${PACKAGE_NAME}.json
    exit 0
fi

echo "Cleanup OSC Repo..."
rm ${OSC_REPO_DIR}/*.tar.gz ${OSC_REPO_DIR}/*.rpm* || true

echo "Download and validate RPM and ASC..."
curl -L -o "${OSC_REPO_DIR}"/${RPM_FILE_NAME} ${RPM_URL}
curl -L -o "${OSC_REPO_DIR}"/${RPM_FILE_NAME}.asc "${RPM_URL}.asc"
rpm -K --nosignature "${OSC_REPO_DIR}"/${RPM_FILE_NAME}


echo "Checkout code repo..."
cd "${SRC_REPO_DIR}"
git clone https://github.com/mullvad/mullvadvpn-app.git
cd mullvadvpn-app
git checkout "${TAG_NAME}"
git submodule update --init --recursive


echo "Generate relay list..."
cargo run -p mullvad-api --bin relay_list --release > "${OSC_REPO_DIR}"/relays.json


echo "Vendor wireguard-go-rs/libwg..."
pushd wireguard-go-rs/libwg
go mod vendor
tar czf "${OSC_REPO_DIR}"/wireguard-vendor.tar.gz --remove-files vendor
popd


echo "Vendor Rust..."
cargo vendor > "${OSC_REPO_DIR}"/cargo-config
tar czf "${OSC_REPO_DIR}"/mullvadvpn-app-vendor.tar.gz --remove-files vendor


echo "Update _service and spec file..."
pushd "${OSC_REPO_DIR}"
awk -v tag_name="${TAG_NAME}" '/^\s*%define ver/ {sub(/[0-9]+\.[0-9]+/, tag_name);}1' ${OSC_SPEC_FILE} > ${OSC_SPEC_FILE}.backup
mv ${OSC_SPEC_FILE}.backup ${OSC_SPEC_FILE}
awk -v tag_name="${TAG_NAME}" '/^\s*<param name="revision">/ {sub(/[0-9]+\.[0-9]+/, tag_name);}1' _service > _service.backup
mv _service.backup _service
popd


echo "Remove source code repo..."
[[ -d "${SRC_REPO_DIR}" ]] && rm -rf "${SRC_REPO_DIR}"

echo "Success!"
