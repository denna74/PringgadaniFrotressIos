#!/bin/bash
#
# Builds the GodotUnityAds iOS plugin used by Ronda Patrol.
#
# Produces:
#   bin/unity-ads-bridge.xcframework          (the Godot bridge static library)
#   vendor/UnityAds.xcframework               (Unity Ads iOS SDK, fetched + cached)
#
# This script must run on macOS with Xcode and Python/SCons (the macos-latest
# GitHub Action runner satisfies all of these). It follows the canonical
# godot-ios-plugins build path: generate the Godot engine headers from the
# 4.7 source, then compile the plugin's Objective-C++ against them.
#
set -euo pipefail

GODOT_TAG="4.7-stable"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
export PATH="$PATH:/opt/homebrew/bin"

# ---------------------------------------------------------------------------
# 1. Fetch the Unity Ads iOS SDK framework (UnityAds.xcframework)
# ---------------------------------------------------------------------------
# Unity ships the SDK as `UnityAds.zip` (containing UnityAds.xcframework) in the
# Assets section of each release on Unity-Technologies/unity-ads-ios. If the
# default URL drifts, set UNITY_ADS_SDK_URL to a direct asset URL, or drop a
# pre-downloaded framework into ios/plugins/unity-ads/vendor/ to bypass this.
UNITY_ADS_VERSION="${UNITY_ADS_VERSION:-4.18.1}"
VENDOR_DIR="$SCRIPT_DIR/vendor"
mkdir -p "$VENDOR_DIR"
XCFRAMEWORK_DIR="$VENDOR_DIR/UnityAds.xcframework"
DEVICE_SWIFT_HEADER="$XCFRAMEWORK_DIR/ios-arm64/UnityAds.framework/Headers/UnityAds-Swift.h"
SIMULATOR_SWIFT_HEADER="$XCFRAMEWORK_DIR/ios-arm64_x86_64-simulator/UnityAds.framework/Headers/UnityAds-Swift.h"

if [ -d "$XCFRAMEWORK_DIR" ] && { [ ! -f "$DEVICE_SWIFT_HEADER" ] || [ ! -f "$SIMULATOR_SWIFT_HEADER" ]; }; then
    echo "==> Removing incomplete Unity Ads XCFramework"
    rm -rf "$XCFRAMEWORK_DIR"
fi

if [ ! -d "$XCFRAMEWORK_DIR" ]; then
    echo "==> Fetching Unity Ads iOS SDK $UNITY_ADS_VERSION"
    URL="${UNITY_ADS_SDK_URL:-https://github.com/Unity-Technologies/unity-ads-ios/releases/download/${UNITY_ADS_VERSION}/UnityAds.zip}"
    TMP="$(mktemp -d)"
    curl -L --fail -o "$TMP/unityads.zip" "$URL"
    unzip -q "$TMP/unityads.zip" -d "$TMP"
    if [ -d "$TMP/UnityAds.xcframework" ]; then
        if [ ! -f "$TMP/UnityAds.xcframework/ios-arm64/UnityAds.framework/Headers/UnityAds-Swift.h" ] \
            || [ ! -f "$TMP/UnityAds.xcframework/ios-arm64_x86_64-simulator/UnityAds.framework/Headers/UnityAds-Swift.h" ]; then
            echo "ERROR: UnityAds.xcframework is missing its device or simulator Swift header."
            exit 1
        fi
        cp -R "$TMP/UnityAds.xcframework" "$XCFRAMEWORK_DIR"
    else
        echo "ERROR: UnityAds.xcframework not found in $URL"
        exit 1
    fi
    rm -rf "$TMP"
else
    echo "==> Reusing cached UnityAds.xcframework"
fi

# ---------------------------------------------------------------------------
# 2. Build the Godot bridge library
# ---------------------------------------------------------------------------
# The bridge compiles against the Godot 4.7 engine headers. We use the official
# godot-ios-plugins harness (its SConstruct globs plugins/<name>/*.{cpp,mm,m}
# and builds against the `godot` submodule). The `godot` submodule must build
# its generated headers first, so this step compiles the engine's iOS target.
PLUGIN_NAME="godot_unity_ads"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Cloning godot-ios-plugins (build harness) — this pulls Godot source"
git clone --recursive --depth 1 https://github.com/godotengine/godot-ios-plugins.git "$WORK/godot-ios-plugins"
cd "$WORK/godot-ios-plugins"

# Pin the Godot submodule to the 4.7 tag.
cd godot
git fetch --depth 1 origin tag "$GODOT_TAG"
git checkout "$GODOT_TAG"
cd ..

# Generate the Godot iOS headers (required to compile any iOS plugin).
echo "==> Building Godot 4.7 iOS headers (takes several minutes)"
cd godot
scons platform=ios target=editor -j2
cd ..

# Install the plugin source into the harness and register it in the SConstruct
# plugin list (the EnumVariable would otherwise reject an unknown plugin name).
PLUGIN_DIR="plugins/$PLUGIN_NAME"
mkdir -p "$PLUGIN_DIR"
cp "$SCRIPT_DIR/src/GodotUnityAds.h" "$SCRIPT_DIR/src/GodotUnityAds.mm" "$PLUGIN_DIR/"
python3 - "$PLUGIN_NAME" "$SCRIPT_DIR" <<'PYEOF'
import sys
name, script_dir = sys.argv[1], sys.argv[2]
with open("SConstruct") as f:
    text = f.read()
marker = "['', 'apn', 'arkit', 'camera', 'icloud', 'gamecenter', 'inappstore', 'photo_picker']"
assert marker in text, "SConstruct plugin list marker not found"
text = text.replace(marker, "['', 'apn', 'arkit', 'camera', 'icloud', 'gamecenter', 'inappstore', 'photo_picker', '%s']" % name)
# Unity Ads is a framework (has a module map); with -fmodules it is only found
# via the framework search path. Add -F pointing at the framework's parent so
# `#import <UnityAds/UnityAds.h>` and `UnityAds-Swift.h` resolve as modules.
framework_parent = script_dir + "/vendor/UnityAds.xcframework/ios-arm64"
fw_marker = "env.Prepend(CXXFLAGS=['-DVULKAN_ENABLED', '-std=gnu++17'])"
assert fw_marker in text, "CXXFLAGS marker not found"
text = text.replace(
    fw_marker,
    fw_marker
    + "\n    env.Append(CCFLAGS=['-F', '%s'])" % framework_parent
    + "\n    env.Append(LINKFLAGS=['-F', '%s', '-framework', 'UnityAds'])" % framework_parent
)
with open("SConstruct", "w") as f:
    f.write(text)
PYEOF

echo "==> Compiling bridge (arm64 device + arm64 simulator)"
# use_llvm=yes selects clang/clang++; the SConstruct emits -fmodules/-fcxx-modules
# and our patch adds -F <UnityAds.xcframework dir>, all of which require Clang's
# module system. GCC's -fmodules is a different implementation that doesn't read
# Clang's module.modulemap, and GCC doesn't recognize -F, so under GCC the
# `#import <UnityAds/UnityAds.h>` lookup fails with "file not found".
# version=4.0 is the generic Godot 4.x flag set used by the harness for all 4.x.
scons use_llvm=yes target=release arch=arm64 plugin=$PLUGIN_NAME version=4.0
scons use_llvm=yes target=release arch=arm64 simulator=yes plugin=$PLUGIN_NAME version=4.0

DEVICE_LIB="./bin/lib$PLUGIN_NAME.arm64-ios.release.a"
SIM_LIB="./bin/lib$PLUGIN_NAME.arm64-simulator.release.a"

xcodebuild -create-xcframework \
    -library "$DEVICE_LIB" \
    -library "$SIM_LIB" \
    -output "$ROOT_DIR/ios/plugins/unity-ads/bin/unity-ads-bridge.xcframework"

echo "==> Build complete: ios/plugins/unity-ads/bin/unity-ads-bridge.xcframework"
