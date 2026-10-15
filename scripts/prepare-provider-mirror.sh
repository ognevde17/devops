#!/usr/bin/env bash
# Optional fallback when registry.terraform.io is unavailable. Run on the VM.
set -euo pipefail
[[ $(uname -s) == Linux ]] || { echo 'Run on the Ubuntu VM.' >&2; exit 2; }
case $(uname -m) in
    x86_64) arch=amd64 ;;
    aarch64) arch=arm64 ;;
    *) echo 'Unsupported architecture' >&2; exit 2 ;;
esac
version=4.6.0
base="https://github.com/kreuzwerker/terraform-provider-docker/releases/download/v$version"
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runtime="$root/.runtime"
mirror="$runtime/providers/registry.terraform.io/kreuzwerker/docker"
mkdir -p "$mirror"
archive="terraform-provider-docker_${version}_linux_${arch}.zip"
curl --fail --location --retry 2 --max-time 120 "$base/$archive" -o "$mirror/$archive"
curl --fail --location --max-time 30 "$base/terraform-provider-docker_${version}_SHA256SUMS" -o "$runtime/provider-SHA256SUMS"
expected=$(awk -v file="$archive" '$2 == file {print $1}' "$runtime/provider-SHA256SUMS")
[[ "$expected" =~ ^[0-9a-f]{64}$ ]] || { echo 'Missing SHA256 in release manifest' >&2; exit 1; }
(cd "$mirror" && printf '%s  %s\n' "$expected" "$archive" | sha256sum --check)
cat > "$runtime/terraform.tfrc" <<EOF
provider_installation {
  filesystem_mirror {
    path = "$runtime/providers"
    include = ["registry.terraform.io/kreuzwerker/docker"]
  }
}
EOF
echo "Provider mirror ready. Use: sudo env TF_CLI_CONFIG_FILE=$runtime/terraform.tfrc terraform -chdir=$root/terraform init"
