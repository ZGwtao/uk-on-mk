#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 UNSW
# SPDX-License-Identifier: BSD-2-Clause

set -eu

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
config="$root/deps/sddf.conf"

# shellcheck source=/dev/null
. "$config"

sddf=${SDDF:-"$root/dep/sddf"}
if [[ -d "$sddf" ]]; then
    exit 0
fi
if [[ -e "$sddf" ]]; then
    echo "sDDF path exists but is not a directory: $sddf" >&2
    exit 1
fi

mkdir -p "$(dirname "$sddf")"
git clone --branch "$SDDF_BRANCH" "$SDDF_URL" "$sddf"
git -C "$sddf" checkout --detach "$SDDF_REV"
