# Troubleshooting

Start from the final useful log line and the exact target/configuration. Do not retry a silent signing failure indefinitely.

| Symptom | Likely contract to inspect | Next evidence |
| --- | --- | --- |
| Bundle identifier cannot be registered | Identifier already belongs to another team | Choose a globally unique owner bundle ID; do not try to remove another team's record |
| “No profiles found” | Team, App ID, device, capability, or profile mismatch | Inspect app target, logged-in team, registered device, profile, and final entitlement request |
| Physical device absent | Pairing, trust, Developer Mode, or CoreDevice tunnel | Run `xcrun devicectl list devices`; inspect installed Xcode help and device state |
| Phone cannot reach local Rails | `localhost` resolves on the phone, not the Mac | Use a reachable LAN address, owner-controlled tunnel, Staging, or Production |
| Archive stalls at provisioning | Hidden target failure or missing provisioning authentication | Remove compact formatter, capture raw `xcodebuild`, and inspect every target's signing inputs |
| Upload key works but archive does not | Fastlane upload auth was not supplied to `xcodebuild` | Authenticate the archive/export phase separately or install explicit profile/signing material |
| New certificate appears after each CI run | Disposable automatic provisioning creates account-side identities | Stop the lane, revoke or clean up orphans, and import reusable signing material |
| Exported IPA lacks Push/Associated Domains | Source entitlements were not authorized or preserved through signing/export | Compare project request, profile, final signature, and export method |
| `BadDeviceToken` | Sandbox/Production endpoint mismatch or invalidated token | Compare stored device environment, signed `aps-environment`, and selected APNs endpoint/key |
| `DeviceTokenNotForTopic` | Wrong bundle-ID topic/team/key | Compare final app ID, APNs topic, and provider key scope |
| TestFlight push fails while Xcode push works | TestFlight token is Production | Confirm per-device environment and Production APNs credential; do not flip a global flag |
| AASA returns 200 but link opens Safari | Entitlement/app ID/domain mismatch, redirect, cache, or unverified install | Inspect final signed domains, AASA app ID and redirect behavior; test from outside the app |
| CI reports only generic Simulator destinations | CoreSimulator did not recache the image's installed runtimes | Run `xcrun simctl list`, record runner/Xcode image, and retry a fresh runner before downloading SDKs |
| Xcode project changes only on one machine | Generated project drift | Regenerate from the pinned spec in a temporary copy and compare project plus shared scheme |

## Keep version-specific failures scoped

One Xcode 26.6 / Fastlane Gym 2.237 prototype hung when Gym combined `clean archive`, while archive-only with a freshly removed lane-owned DerivedData directory succeeded. The same Gym version also appended ordinary `xcargs` to archive and export, so duplicating Xcode authentication flags in `export_xcargs` caused duplicate-argument failure.

Treat those as version-labelled diagnostics, not timeless defaults. Before applying them:

1. record Xcode, macOS runner image, Fastlane, and project versions;
2. print the raw generated `xcodebuild` command;
3. reproduce the smaller failing phase;
4. check current upstream behavior;
5. retain the workaround only while the locked versions need it.

## Stop at the right boundary

If a third-party managed signer fails after accepting the app's documented artifact, report the artifact revision, digest, identity request, and public error contract. Do not reach into the provider's private key store, policy engine, or tester administration from the application repository.
