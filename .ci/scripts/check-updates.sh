#!/usr/bin/env bash
set -e

current_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
repo_dir=$(realpath "${current_dir}/../../")

. ${current_dir}/common.sh
. ${current_dir}/packages.sh

for package in "${packages[@]}"; do
    update_if_needed "${package}"
done
