# Support status

Use this date-stamped status to distinguish maintained guidance from a pathway that still needs proof in the target
app. It is a consumer-facing confidence statement, not a maintainer ledger and not permission to mutate this
installed Skill.

## Evidence levels

- **Documented:** supported by a current primary source but not exercised in a reference app.
- **Compiled:** passed an unsigned build or Simulator test.
- **Development-device verified:** installed and observed on a physical device with Development signing.
- **TestFlight verified:** processed, installed, and observed through TestFlight.
- **App Store verified:** released through the owner's store record.
- **Negative result:** reproduced failure that rules out a proposed default.

The target app still needs its own evidence. A successful reference experiment never proves a different bundle ID,
team, entitlement set, server origin, or device.

## Maintainer-verified findings — July 2026

| Finding | Confidence |
| --- | --- |
| One conventional Xcode project can support GUI, CLI, CI, physical-device, and TestFlight workflows | Development-device and TestFlight verified |
| A pinned XcodeGen spec plus committed project can provide reviewable generation and zero-setup Xcode opening | Compiled; CI drift check verified |
| `xcodebuild` plus `devicectl` can build, install, and launch on a paired iPhone without opening Xcode | Development-device verified |
| GitHub-hosted macOS can build a credential-free universal unsigned Simulator app archive, and one Debug artifact can use validated per-launch origins | Compiled; hosted-Simulator launch against two origins observed |
| GitHub-hosted macOS can build, sign, inspect, and upload the canonical project | TestFlight upload and processing verified |
| Development installs receive Sandbox APNs tokens while TestFlight installs receive Production tokens | Sandbox physical receipt and TestFlight registration verified; persist the environment per device |
| API-key-only automatic provisioning on disposable runners can leave orphaned account-side certificates | Negative result reproduced; reusable signing material is the maintained default |
| A separate preview wrapper or Swift Playground can drift and omit the shipping entitlement surface | Negative architecture result |

The detailed experiment history lives in maintainers' private reference applications and expiring CI logs. The
durable public review rationale is preserved in
[the deployment Skill pull request](https://github.com/raghubetina/hotwire-native-agent-kit/pull/5).

## Advisory paths that still require target-specific proof

- A deliberately reduced-entitlement Personal Team configuration on an actually unpaid Apple account.
- A new owner's reusable `.p12` and profile path from clean bootstrap through a TestFlight install.
- Distinct owner Staging and Production lanes with their own identities, Associated Domains, and APNs.
- Ad Hoc distribution to registered devices.
- External TestFlight beta review and invitation at the target tester scale.
- Public App Store submission and transfer/graduation from a managed preview.
- The full Production push matrix: foreground, background, terminated receipt, and warm/cold notification taps.

Present these as advisory until the target app completes the corresponding proof. Record target evidence in that
application's release notes or deployment report, not by editing this installed Skill.
