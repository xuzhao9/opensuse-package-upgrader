#!/usr/bin/env bash

# Shared OBS branch, build, and submit workflow for packages in science.

obs_prepare_branch() {
    local package=$1
    local branch_root

    OBS_BRANCH_PROJECT=${OBS_BRANCH_PROJECT:-home:nuklly:branches:science}
    mkdir -p /tmp/osc-packager
    branch_root=$(mktemp -d "/tmp/osc-packager/${package}-branch.XXXXXX")
    OBS_BRANCH_DIR="${branch_root}/${package}"

    osc branch --nodevelproject science "$package" "$OBS_BRANCH_PROJECT"
    osc checkout -o "$OBS_BRANCH_DIR" "$OBS_BRANCH_PROJECT" "$package"
    echo "Branched checkout: $OBS_BRANCH_DIR"
}

obs_build_result() {
    local package=$1
    local repository=$2
    local arch=$3

    osc results --xml -r "$repository" -a "$arch" "$OBS_BRANCH_PROJECT" "$package" |
        python3 -c '
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.stdin).getroot()
results = root.findall("result")
if len(results) != 1:
    raise SystemExit("Expected exactly one build result")
result = results[0]
statuses = [s for s in result.findall("status") if s.get("package") == sys.argv[1]]
if len(statuses) != 1:
    raise SystemExit("Expected exactly one package status")
dirty = result.get("dirty") == "true" or statuses[0].get("dirty") == "true"
print(root.get("state", ""), statuses[0].get("code", ""), str(dirty).lower(), sep="\t")
' "$package"
}

obs_built_version() {
    local package=$1
    local repository=$2
    local arch=$3

    osc api "/build/${OBS_BRANCH_PROJECT}/${repository}/${arch}/${package}/_history" |
        python3 -c '
import sys
import xml.etree.ElementTree as ET

entries = ET.parse(sys.stdin).getroot().findall("entry")
if not entries:
    raise SystemExit("No completed builds")
print(entries[-1].get("versrel", ""))
'
}

obs_finish_update() {
    local package=$1
    local version=$2
    local repository=${OBS_TEST_REPOSITORY:-openSUSE_Tumbleweed}
    local arch=${OBS_TEST_ARCH:-x86_64}
    local timeout=${OBS_BUILD_TIMEOUT_SECONDS:-14400}
    local baseline="" result state status dirty built_version start
    local build_passed=false

    (cd "$OBS_BRANCH_DIR" && osc service mr && osc addremove)
    baseline=$(obs_build_result "$package" "$repository" "$arch" 2>/dev/null | cut -f1) || baseline=""
    (cd "$OBS_BRANCH_DIR" && osc commit -m "Update $package to $version")

    echo "Waiting for $package build in $OBS_BRANCH_PROJECT ($repository/$arch)..."
    start=$SECONDS
    while (( SECONDS - start < timeout )); do
        if result=$(obs_build_result "$package" "$repository" "$arch"); then
            IFS=$'\t' read -r state status dirty <<< "$result"
            if [[ -n "$state" && "$state" != "$baseline" && "$dirty" != true ]]; then
                case "$status" in
                    succeeded)
                        if built_version=$(obs_built_version "$package" "$repository" "$arch" 2>/dev/null) &&
                           [[ "$built_version" == "$version"-* ]]; then
                            build_passed=true
                            break
                        fi
                        ;;
                    failed|unresolvable|broken|disabled|excluded)
                        echo "Test build ended with status: $status" >&2
                        return 1
                        ;;
                esac
            fi
        fi
        sleep 30
    done

    if [[ "$build_passed" != true ]]; then
        echo "Timed out waiting for a successful test build." >&2
        return 1
    fi

    osc submitrequest --yes --nodevelproject \
        -m "Update $package to $version" \
        "$OBS_BRANCH_PROJECT" "$package" science "$package"
}
