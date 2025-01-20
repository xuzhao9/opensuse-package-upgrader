#!/usr/bin/env bash
set -e

current_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
repo_dir=$(realpath "${current_dir}/../../")

. ${current_dir}/common.sh
. ${current_dir}/packages.sh

for package in "${packages[@]}"; do
    check_update_dump_json "${package}"
done

# Read from the json outputs and generate the svg file
python3 "${repo_dir}/tools/gen_svg.py" --json_dir ${repo_dir}/.data/json
