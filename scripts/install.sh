#!/usr/bin/env bash
# Download a serpentine release, unpack it into the runner tool cache and put it on PATH.
#
# Shared by both actions in this repository. The runner supplies RUNNER_OS, RUNNER_ARCH,
# RUNNER_TOOL_CACHE, RUNNER_TEMP, GITHUB_PATH and GITHUB_OUTPUT; the action supplies
# SERPENTINE_VERSION.
set -euo pipefail

readonly REPO="Serpent-Tools/serpentine"

die() {
    echo "::error::$*" >&2
    exit 1
}

# The tag of the latest release, read off the redirect so no API token is needed.
latest_version() {
    local url
    url=$(curl --fail --silent --show-error --location --head --output /dev/null \
        --write-out '%{url_effective}' "https://github.com/$REPO/releases/latest")
    [[ $url =~ /tag/v?(.+)$ ]] || die "no version in the latest release url: $url"
    printf '%s' "${BASH_REMATCH[1]}"
}

[[ ${RUNNER_OS:-} == Linux ]] || die \
    "serpentine-action only supports Linux runners; a pipeline needs a docker or podman daemon, which ${RUNNER_OS:-this runner} does not have."

case ${RUNNER_ARCH:-} in
    X64) target="x86_64-unknown-linux-gnu" ;;
    ARM64) target="aarch64-unknown-linux-gnu" ;;
    *) die "serpentine has no Linux release for ${RUNNER_ARCH:-an unknown architecture}" ;;
esac

version=${SERPENTINE_VERSION:-latest}
if [[ $version == latest ]]; then
    version=$(latest_version)
else
    version=${version#v}
fi

install_dir="$RUNNER_TOOL_CACHE/serpentine/$version/$RUNNER_ARCH"
binary="$install_dir/serpentine"

if [[ -x $binary ]]; then
    echo "serpentine $version is already in the tool cache"
else
    echo "Installing serpentine $version for $target"

    archive="serpentine-$version-$target.tar.gz"
    base_url="https://github.com/$REPO/releases/download/v$version"

    staging=$(mktemp --directory "$RUNNER_TEMP/serpentine.XXXXXX")
    trap 'rm -rf "$staging"' EXIT

    curl --fail --silent --show-error --location \
        --output "$staging/$archive" "$base_url/$archive" \
        || die "could not download $archive, is v$version a released version?"
    curl --fail --silent --show-error --location \
        --output "$staging/SHA256SUMS" "$base_url/SHA256SUMS" \
        || die "release v$version does not publish a SHA256SUMS file"

    # --ignore-missing would pass vacuously if the archive were absent from the list, so pick the
    # one line out and check that.
    awk -v want="$archive" '$2 == want' "$staging/SHA256SUMS" > "$staging/wanted"
    [[ -s $staging/wanted ]] || die "$archive is not listed in the SHA256SUMS of v$version"
    (cd "$staging" && sha256sum --check wanted) \
        || die "$archive does not match the checksum published for v$version"

    mkdir -p "$install_dir"
    # The archive wraps everything in a serpentine-<version>-<target>/ directory.
    tar --extract --gzip --strip-components=1 \
        --file "$staging/$archive" --directory "$install_dir"
fi

echo "$install_dir" >> "$GITHUB_PATH"
{
    echo "version=$version"
    echo "path=$install_dir"
    echo "binary=$binary"
} >> "$GITHUB_OUTPUT"
