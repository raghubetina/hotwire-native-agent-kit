# Direct-device preview

Use this lane for the fastest physical-iPhone proof. It is a Development install, not a TestFlight or App Store
release.

## Preflight without changing Apple resources

1. Run the project audit and inspect enabled shared-scheme environment variables. An iPhone resolves `localhost` to
   itself, not the Mac. Choose a reachable owner-controlled Staging/Production URL, LAN address, or tunnel.
2. Confirm full Xcode is selected with `xcode-select -p` and record `xcodebuild -version`.
3. List paired devices with `xcrun devicectl list devices`. The phone must be unlocked, trusted, paired, and in
   Developer Mode.
4. Record the app target, shared scheme, Debug configuration, bundle ID, requested team ID, entitlements, and
   available signing identity/profile metadata.
5. Ask the owner to confirm that the selected Apple team is theirs and intended for this app. A team ID in project
   settings or a certificate on the Mac proves configuration/access, not legal ownership.

A free Personal Team needs its own intentionally reduced-entitlement Development configuration. Remove unsupported
Push Notifications and Associated Domains from that configuration before building; do not silently weaken the paid
team or release target.

## Use the Xcode GUI when it is the clearest first proof

1. Open the canonical `.xcworkspace` when dependencies require one; otherwise open the `.xcodeproj`.
2. Select the application scheme in the toolbar, then select the paired iPhone as the run destination.
3. Open the application target's **Signing & Capabilities** tab and verify the intended team and bundle ID. Leave
   test targets free of application-only capabilities.
4. Edit **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables** when selecting a reachable
   Rails origin. Keep the override Debug/Run-only.
5. Press **Run**. If Xcode proposes registering an App ID/device, creating or replacing a profile/certificate, or
   changing capabilities, stop and obtain the owner's approval for that exact Apple-account mutation.

## Use the command line for repeatable runs

Ask the installed tools for current syntax first:

```sh
xcodebuild -help
xcrun devicectl help
```

With an existing valid Development identity/profile, the ordinary shape is:

```sh
xcodebuild \
  -project path/to/App.xcodeproj \
  -scheme App \
  -configuration Debug \
  -destination "id=$DEVICE_UDID" \
  -derivedDataPath build/device \
  build

xcrun devicectl device install app \
  --device "$DEVICE_UDID" \
  build/device/Build/Products/Debug-iphoneos/App.app
```

Locate the actual product from build settings/output rather than assuming that example path. Do not add
`-allowProvisioningUpdates` reflexively: it authorizes Xcode to change account-side provisioning. Inventory the
missing resource and obtain approval first.

Launch or stream logs with the current `devicectl` subcommand supported by the installed Xcode. Preserve raw
`xcodebuild` output when signing fails.

## Prove the result

Inspect the built `.app` with the bundled artifact inspector, including `--expect-channel development`, the exact
bundle/team, the baked or Debug-selected Rails origin, and any expected Sandbox APNs or Associated Domains
entitlements. Then observe on the physical phone:

- app launch and the intended Rails origin;
- authentication across process termination;
- navigation and external links;
- camera/permission behavior requested by the product;
- Universal Links or Sandbox push only when the paid Development profile authorizes them.

Record the device model/OS, Xcode version, source SHA/dirty state, team, bundle ID, profile UUID/expiration, artifact
digest, signed entitlements, Rails origin, and observed behavior. A successful install alone proves neither the
server origin nor the device capability.

Primary references:

- <https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices>
- <https://developer.apple.com/help/account/devices/register-a-single-device/>
- <https://developer.apple.com/help/account/basics/about-your-developer-account/>
