# Unity Ads iOS plugin (Godot 4.7)

Bridges the Unity Ads iOS SDK to Godot as the native `GodotUnityAds` singleton,
using the GDScript interface in `autoload/UnityAds.gd`.

## Files

- `unity-ads.gdip` — Godot iOS plugin manifest. Enable it under
  **Project → Export → iOS → Plugins → UnityAds**.
- `src/GodotUnityAds.h` / `src/GodotUnityAds.mm` — Objective-C++ bridge. Registers
  `GodotUnityAds` and forwards Unity Ads delegate callbacks to Godot signals on
  the main thread.
- `build.sh` — builds the bridge `xcframework` and vendors the Unity Ads iOS SDK.
  **macOS/Xcode/SCons only** (runs on the CI `macos-latest` runner), because the
  bridge compiles against generated Godot engine headers.
- `bin/` — output of `build.sh` (`unity-ads-bridge.xcframework`).
- `vendor/` — Unity Ads iOS SDK (`UnityAds.xcframework`).

## Signals (match the Android plugin)

`initialized`, `init_failed`, `ad_loaded`, `ad_load_failed`, `ad_completed`,
`ad_show_failed`, `rewarded`.

## Build

The CI `distribute.yml` job runs `build.sh` before export. To build manually
from the project root on macOS:

```bash
./ios/plugins/unity-ads/build.sh
```

The Unity Ads iOS SDK is fetched from a configurable URL
(`UNITY_ADS_SDK_URL` / `UNITY_ADS_VERSION`); if the tarball path drifts, place
`vendor/UnityAds.xcframework` manually and the fetch is skipped. Set your real
Game ID in **Project Settings → unity_ads → ios → game_id**.

## Production readiness

- Set the iOS Game ID and rewarded placement to the values from Unity Dashboard.
- Set `test_mode` to `false` for production.
- Add the SKAdNetwork identifiers for your Unity Ads account to the app's
  `Info.plist` (Unity provides the exact list for your Game ID).
