#!/usr/bin/env bash
# shellcheck disable=SC1091
#
# Local macOS ARM64 production build script for VSCodium.
# Mirrors the CI workflow at .github/workflows/stable-macos.yml.
#
# Usage:
#   ./build_mac.sh          full build (source + compile + .app)
#   ./build_mac.sh -s       skip source clone (reuse existing vscode dir)
#   ./build_mac.sh -p       also package assets (zip / dmg) into assets/
#
# Output: VSCode-darwin-arm64/VSCodium.app

set -e

export APP_NAME="VSCodium"
export ASSETS_REPOSITORY="VSCodium/vscodium"
export BINARY_NAME="codium"
export CI_BUILD="no"
export GH_REPO_PATH="VSCodium/vscodium"
export ORG_NAME="VSCodium"
export OS_NAME="osx"
export SHOULD_BUILD="yes"
export SHOULD_BUILD_REH="no"
export SHOULD_BUILD_REH_WEB="no"
export VSCODE_ARCH="arm64"
export VSCODE_QUALITY="stable"
export VSCODE_SKIP_NODE_VERSION_CHECK="yes"
export NODE_OPTIONS="--max-old-space-size=8192"

SKIP_SOURCE="no"
SKIP_ASSETS="yes"

while getopts ":sp" opt; do
  case "$opt" in
    s) SKIP_SOURCE="yes" ;;
    p) SKIP_ASSETS="no" ;;
    *) ;;
  esac
done

echo "OS_NAME=\"${OS_NAME}\""
echo "VSCODE_ARCH=\"${VSCODE_ARCH}\""
echo "VSCODE_QUALITY=\"${VSCODE_QUALITY}\""
echo "SKIP_SOURCE=\"${SKIP_SOURCE}\""
echo "SKIP_ASSETS=\"${SKIP_ASSETS}\""

# Source step
if [[ "${SKIP_SOURCE}" == "no" ]]; then
  rm -rf vscode VSCode-darwin-arm64 vscode-reh-darwin-arm64 vscode-reh-web-darwin-arm64

  . get_repo.sh
  . version.sh

  # Persist for -s re-runs
  echo "MS_TAG=\"${MS_TAG}\""         > dev/build.env
  echo "MS_COMMIT=\"${MS_COMMIT}\""  >> dev/build.env
  echo "RELEASE_VERSION=\"${RELEASE_VERSION}\"" >> dev/build.env
  echo "BUILD_SOURCEVERSION=\"${BUILD_SOURCEVERSION}\"" >> dev/build.env
else
  . dev/build.env
  echo "MS_TAG=\"${MS_TAG}\""
  echo "MS_COMMIT=\"${MS_COMMIT}\""
  echo "RELEASE_VERSION=\"${RELEASE_VERSION}\""

  # Reset vscode tree to bare checkout, stripping any previously applied patches
  cd vscode
  git add .
  git reset -q --hard HEAD
  while [[ -n "$( git log -1 | grep "VSCODIUM HELPER" )" ]]; do
    git reset -q --hard HEAD~
  done
  rm -rf .build out*
  cd ..
fi

# Build step
. build.sh

# Rebuild native addons for Electron
#
# The gulp packaging step does not run @electron/rebuild, so native .node
# addons are shipped without binaries. Rebuild them here against the bundled
# Electron version so the .app launches correctly.
ELECTRON_VERSION="$( node -p "require('./VSCode-darwin-arm64/VSCodium.app/Contents/Resources/app/node_modules/electron/package.json').version" 2>/dev/null || echo "" )"
if [[ -n "${ELECTRON_VERSION}" ]]; then
  echo "Rebuilding native addons for Electron ${ELECTRON_VERSION} arm64..."
  pushd "VSCode-darwin-arm64/VSCodium.app/Contents/Resources/app" > /dev/null
  npx @electron/rebuild --version "${ELECTRON_VERSION}" --arch arm64
  popd > /dev/null
fi

# Package step (opt-in via -p)
if [[ "${SKIP_ASSETS}" == "no" ]]; then
  . prepare_assets.sh
fi

echo ""
echo "Build complete → VSCode-darwin-arm64/VSCodium.app"
