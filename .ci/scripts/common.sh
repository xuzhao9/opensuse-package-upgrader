#!/usr/bin/env bash
set -e
current_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
repo_dir=$(realpath "${current_dir}/../../")
workdir="${repo_dir}/.workdir"
mkdir -p "${workdir}"

# Utils to update the package
function check_update() {
    obs_path=$1
    obs_pkg_name=$(basename "${obs_path}")
    pushd "${workdir}"
    osc co "${obs_path}/${obs_pkg_name}.spec"
    popd
    if [ ! -f "${workdir}/${obs_pkg_name}.spec" ]; then
        echo "${workdir}/${obs_pkg_name}.spec must exist to proceed."
        exit 1
    fi
    bash "${repo_dir}/packages/${obs_pkg_name}/updater.sh" ${workdir} -c | \
        tee "${workdir}/${obs_pkg_name}.log"
}

function checkout() {
    obs_path=$1
    pushd "${workdir}"
    osc co "${obs_path}"
    popd
}

function update() {
    obs_path=$1
    osc_path=${workdir}/${obs_path}
    osc_pkg_name=$(basename ${osc_path})
    bash "${repo_dir}/packages/${osc_pkg_name}/updater.sh" "${osc_path}"
}

function commit() {
    obs_path=$1; shift
    osc_path="${workdir}/${obs_path}"
    osc_pkg_name=$(basename "${osc_path}")
    old_version=$(awk '/^The current version/ {match($0, /update: (.*) -> (.*)/, ary);print ary[1]}' $workdir/$osc_pkg_name.log)
    new_version=$(awk '/^The current version/ {match($0, /update: (.*) -> (.*)/, ary);print ary[2]}' $workdir/$osc_pkg_name.log)
    pushd "${osc_path}"
    osc ci -m "update from ${old_version} to ${new_version}"
    popd
}

function update_if_needed() {
    obs_path=$1
    osc_pkg_name=$(basename ${obs_path})
    check_update "${obs_path}"
    if ! grep -q "Skipping the update" "${workdir}/${osc_pkg_name}.log"; then
        checkout "${obs_path}"
        update "${obs_path}"
        commit "${obs_path}"
    fi
}
