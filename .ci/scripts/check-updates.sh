#!/usr/bin/env bash
set -e

current_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
repo_dir=$(realpath "${current_dir}/../../")

. ${current_dir}/common.sh

update_if_needed "home:nuklly/mullvadvpn"
update_if_needed "home:nuklly:branches:devel:languages:misc/chezscheme"
update_if_needed "home:nuklly:branches:multimedia:apps/yacreader"
update_if_needed "home:nuklly:branches:server:messaging/telegram-desktop"
