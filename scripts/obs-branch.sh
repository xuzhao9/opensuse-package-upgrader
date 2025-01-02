#!/usr/bin/env bash
# Branch and check out a OBS package
PACKAGE_NAME=$1

declare -A package_dict=(
    ["chezscheme"]="devel:languages:misc/chezscheme"
    ["yacreader"]="multimedia:apps/yacreader"
    ["mullvadvpn"]="home:nuklly/mullvadvpn"
)
