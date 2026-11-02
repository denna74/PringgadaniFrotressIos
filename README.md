# Pringgadani Fortress iOS

iOS port of Pringgadani Fortress, built with Godot 4.7. Game scenes, assets,
and gameplay scripts are carried over from the Android project; iOS uses
StoreKit 2 through OpenIAP and rewarded ads through the Unity Ads iOS bridge.

## App Store configuration

- Bundle identifier: `com.pringgadanifortress`
- Minimum iOS version: 17.0 (required by the bundled OpenIAP frameworks)
- In-app purchase products:
  - `com.pringgadanifortress.instant_gold_1`
  - `com.pringgadanifortress.instant_gold_2`
  - `com.pringgadanifortress.instant_gold_3`

Register the bundle identifier and consumable products in App Store Connect.
If the registered bundle identifier differs, update `export_presets.cfg`,
`fastlane/Fastfile`, both workflow files, and `autoload/IAPConfig.gd` to match.

Set the iOS Unity Ads game ID and rewarded placement under
**Project Settings → Unity Ads → iOS** before testing rewarded ads. The Android
game ID is intentionally not reused.

## Local export

Install Godot 4.7 and the matching iOS export templates, then run:

```bash
godot --headless --import
godot --headless --export-release "iOS" build/ios/PringgadaniFortress.xcodeproj
```

The Unity Ads bridge and SDK are built on macOS with Xcode by
`ios/plugins/unity-ads/build.sh`. OpenIAP's iOS frameworks are included under
`addons/godot-iap/bin/ios`.

## TestFlight delivery

The GitHub Actions workflows export the Xcode project, build it with Fastlane,
and upload the IPA to TestFlight. Configure these repository secrets:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_KEY` (base64-encoded `.p8` key)
- `BUILD_CERTIFICATE_P12` (base64 of an Apple Distribution `.p12` containing its private key)
- `BUILD_CERTIFICATE_P12_PASSWORD` (only if the `.p12` is password-protected)
- `IOS_TEAM_ID`

Reuse a valid Apple Distribution certificate from your Apple Developer team
(for example, the `.p12` artifact from another app in the same team); do not
create a new distribution certificate just for this project. Base64-encode the
`.p12` file itself, not its containing ZIP:

```bash
base64 -w 0 certificate.p12
```

The workflow imports the certificate using an empty password unless
`BUILD_CERTIFICATE_P12_PASSWORD` is set. The profile name defaults to
`PringgadaniFortress AppStore`; set the optional
`IOS_PROVISIONING_PROFILE_NAME` repository variable to override it.

Use **Actions → Check IAP Products → Run workflow** to verify product IDs and
their App Store Connect states.
