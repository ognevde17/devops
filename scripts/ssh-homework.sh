#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ $# -lt 1 || ! "$1" =~ ^[a-z_][a-z0-9_-]*@[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
    echo 'Usage: ssh-homework.sh USER@HOST [REMOTE_COMMAND]' >&2
    exit 2
fi
target=$1
shift
exec ssh -F /dev/null -o IdentityAgent=none -o IdentitiesOnly=yes \
    -i "$root/.runtime/id_ed25519_homework" \
    -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$root/.runtime/remote-known-hosts" \
    "$target" "$@"
