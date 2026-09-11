#!/usr/bin/env bash
#
# Install Harbor Lens.app into /Applications (or ~/Applications).
#
# Usage: scripts/install.sh [options]
#
# Options:
#   -d, --debug       Install the Debug build (default: Release)
#   -u, --user        Install to ~/Applications instead of /Applications
#   -D, --dest DIR    Install to DIR
#   -n, --no-build    Install the existing build without rebuilding
#   -o, --open        Launch Harbor Lens after installing
#   -h, --help        Show this help
#
# Environment:
#   DERIVED_DATA      Build output directory (default: <repo>/.build)
#
# By default the Release build is refreshed with scripts/build.sh and then
# copied to /Applications. Use -u if /Applications is not writable.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_script="$repo_root/scripts/build.sh"
app_name="Harbor Lens"
derived_data="${DERIVED_DATA:-$repo_root/.build}"

configuration="Release"
destination=""
user_destination=false
build=true
open_after=false

usage() {
	cat <<EOF
Usage: $(basename "$0") [options]

Build and install $app_name.app.

Options:
  -d, --debug       Install the Debug build (default: Release)
  -u, --user        Install to ~/Applications instead of /Applications
  -D, --dest DIR    Install to DIR
  -n, --no-build    Install the existing build without rebuilding
  -o, --open        Launch $app_name after installing
  -h, --help        Show this help

Environment:
  DERIVED_DATA      Build output directory (default: $repo_root/.build)
EOF
}

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

info() {
	printf '\n==> %s\n' "$*"
}

while (($#)); do
	case "$1" in
	-d | --debug) configuration="Debug" ;;
	--release) configuration="Release" ;;
	-u | --user)
		user_destination=true
		destination="$HOME/Applications"
		;;
	-D | --dest)
		[[ $# -ge 2 ]] || die "--dest requires a directory"
		destination="$2"
		shift
		;;
	-n | --no-build) build=false ;;
	-o | --open) open_after=true ;;
	-h | --help)
		usage
		exit 0
		;;
	--) shift && break ;;
	-*) die "unknown option: $1 (try --help)" ;;
	*) die "unexpected argument: $1 (try --help)" ;;
	esac
	shift
done

if [[ -z "$destination" ]]; then
	destination="/Applications"
fi
if [[ "$destination" != /* ]]; then
	destination="$PWD/$destination"
fi
if [[ "$user_destination" == true ]]; then
	mkdir -p "$destination" || die "could not create $destination"
fi

if [[ "$build" == true ]]; then
	[[ -x "$build_script" ]] || die "build script not found at $build_script"
	build_args=()
	[[ "$configuration" == "Debug" ]] && build_args+=(--debug)
	"$build_script" ${build_args[@]+"${build_args[@]}"} || die "$app_name failed to build"
fi

source_app="$derived_data/Build/Products/$configuration/$app_name.app"
[[ -d "$source_app" ]] ||
	die "no $configuration build at $source_app; run scripts/build.sh first or drop --no-build"

[[ -d "$destination" ]] || die "destination does not exist: $destination"
[[ -w "$destination" ]] ||
	die "no write permission for $destination; use --user or run with sudo"

if pgrep -xq "$app_name" 2>/dev/null; then
	info "Quitting running copy of $app_name"
	osascript -e "tell application \"$app_name\" to quit" >/dev/null 2>&1 ||
		pkill -x "$app_name" ||
		true
	sleep 1
fi

target_app="$destination/$app_name.app"
[[ -e "$target_app" ]] && rm -rf "$target_app"

info "Installing to $target_app"
ditto "$source_app" "$target_app"
[[ -d "$target_app" ]] || die "copy to $target_app failed"

info "Installed $target_app"
if [[ "$open_after" == true ]]; then
	open "$target_app"
fi
