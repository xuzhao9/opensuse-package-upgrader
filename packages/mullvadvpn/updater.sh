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
OSC_REPO_DIR="$1"
# Check that ${OSC_REPO_DIR}/mullvadvpn.spec exists
if [ ! -f "${OSC_REPO_DIR}"/mullvadvpn.spec ]; then
    echo "${OSC_REPO_DIR}/mullvadvpn.spec must exist to proceed."
    exit 1
fi

ARCH="x86_64"

# Get tag_name, rpm url, and rpm_sig_url
SRC_REPO_DIR="/tmp/${USER}/osc-packager/"
REL_URL="https://api.github.com/repos/mullvad/mullvadvpn-app/releases"
[[ -d "${SRC_REPO_DIR}" ]] && rm -rf "${SRC_REPO_DIR}"
mkdir -p "${SRC_REPO_DIR}"
curl -o "${SRC_REPO_DIR}"/release_list.json "${REL_URL}"
# By default, we do not package beta version
TAG_NAME=$(jq -r '.[] | select(.tag_name | contains("beta") or contains("android") | not) | .tag_name' "${SRC_REPO_DIR}"/release_list.json | head -n 1)
RPM_URL=$(jq -r --arg TAG_NAME "${TAG_NAME}" --arg ARCH "${ARCH}" '.[] | select(.tag_name == $TAG_NAME) | .assets[] | select(.browser_download_url | endswith($ARCH + ".rpm")) | .browser_download_url' /tmp/xz/osc-packager/release_list.json)
RPM_FILE_NAME=$(basename ${RPM_URL})

echo "Getting current repo revision..."
CURRENT_TAG=$(awk '/^\s*%define ver/ {match($0, /[0-9]+\.[0-9]+/, ary);print ary[0]}' mullvadvpn.spec)
if [[ $CURRENT_TAG == $TAG_NAME ]]; then
    echo "The current tag is the latest: ${TAG_NAME}. Skipping the update."
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
cargo run --bin relay_list --release > "${OSC_REPO_DIR}"/relays.json


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
awk -v tag_name="${TAG_NAME}" '/^\s*%define ver/ {sub(/[0-9]+\.[0-9]+/, tag_name);}1' mullvadvpn.spec > mullvadvpn.spec.backup
mv mullvadvpn.spec.backup mullvadvpn.spec
awk -v tag_name="${TAG_NAME}" '/^\s*<param name="revision">/ {sub(/[0-9]+\.[0-9]+/, tag_name);}1' _service > _service.backup
mv _service.backup _service
popd


echo "Remove source code repo..."
[[ -d "${SRC_REPO_DIR}" ]] && rm -rf "${SRC_REPO_DIR}"

echo "Success!"
