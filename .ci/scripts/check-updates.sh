#!/usr/bin/env bash
set -e

current_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
repo_dir=$(realpath "${current_dir}/../../")
workdir=$repo_dir/.workdir
mkdir -p $workdir

# check out mullvadvpn.spec exists
pushd $workdir
osc co home:nuklly/mullvadvpn/mullvadvpn.spec
popd
# make sure check out successful
if [ ! -f "$workdir"/mullvadvpn.spec ]; then
    echo "$workdir/mullvadvpn.spec must exist to proceed."
    exit 1
fi

# check mullvadvpn version
# -c: check version only
bash "${repo_dir}"/packages/mullvadvpn/updater.sh $workdir -c | tee $workdir/mullvadvpn.log
# if there is an update, do the update and build
if grep -q "Skipping the update" $workdir/mullvadvpn.log; then
    echo "Mullvadvpn is updated."
else
    pushd $workdir
    osc co home:nuklly/mullvadvpn
    popd
    mullvadvpn_workdir="$workdir/home:nuklly/mullvadvpn"
    old_version=$(awk '/^The current version/ {match($0, /update: (.*) -> (.*)/);print ary[1]}' $workdir/mullvadvpn.log)
    new_version=$(awk '/^The current version/ {match($0, /update: (.*) -> (.*)/);print ary[2]}' $workdir/mullvadvpn.log)
    bash "${repo_dir}"/packages/mullvadvpn/updater.sh ${mullvadvpn_workdir}
    osc ci -m "update from ${old_version} to ${new_version}"
    echo "Mullvadvpn is updated."
fi
