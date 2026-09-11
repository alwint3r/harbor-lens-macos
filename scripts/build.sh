#!/usr/bin/env bash
#
# Build Harbor Lens.app with xcodebuild.
#
# Usage: scripts/build.sh [options]
#
# Options:
#   -d, --debug       Build the Debug configuration (default: Release)
#   -t, --tests       Run the unit tests after building
#   -c, --clean       Clean the scheme before building
#   -h, --help        Show this help
#
# Environment:
#   DERIVED_DATA      Build output directory (default: <repo>/.build)
#
# The built app is left at:
#   $DERIVED_DATA/Build/Products/<configuration>/Harbor Lens.app

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="$repo_root/HarborTrajectoryViewer.xcodeproj"
scheme="HarborTrajectoryViewer"
app_name="Harbor Lens"
derived_data="${DERIVED_DATA:-$repo_root/.build}"

configuration="Release"
configuration_explicit=false
run_tests=false
clean=false

usage() {
	cat <<EOF
Usage: $(basename "$0") [options]

Build $app_name.app with xcodebuild.

Options:
  -d, --debug       Build the Debug configuration (default: Release)
  -r, --release     Build the Release configuration
  -t, --tests       Run the unit tests (Debug only; adds the test action)
  -c, --clean       Clean the scheme before building
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
	-d | --debug)
		configuration="Debug"
		configuration_explicit=true
		;;
	-r | --release)
		configuration="Release"
		configuration_explicit=true
		;;
	-t | --tests) run_tests=true ;;
	-c | --clean) clean=true ;;
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

if [[ "$run_tests" == true && "$configuration" == "Release" ]]; then
	if [[ "$configuration_explicit" == true ]]; then
		die "unit tests run in the Debug configuration; drop --release or pass --debug"
	fi
	configuration="Debug"
fi

[[ -d "$project" ]] || die "Xcode project not found at $project"
command -v xcodebuild >/dev/null 2>&1 ||
	die "xcodebuild not found; install Xcode and run 'xcode-select -s /Applications/Xcode.app'"

actions=()
[[ "$clean" == true ]] && actions+=(clean)
actions+=(build)
[[ "$run_tests" == true ]] && actions+=(test)

info "Building $app_name ($configuration)"
xcodebuild \
	-project "$project" \
	-scheme "$scheme" \
	-configuration "$configuration" \
	-destination 'platform=macOS' \
	-derivedDataPath "$derived_data" \
	CODE_SIGNING_ALLOWED=NO \
	"${actions[@]}"

app="$derived_data/Build/Products/$configuration/$app_name.app"
[[ -d "$app" ]] || die "build finished but $app is missing"

info "Built $app"
