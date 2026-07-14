# Evidence ledger

Use this file to keep recommendations tied to proof. Add a finding only when it should change how another owned app is built, audited, or tested.

## Evidence levels

- **Documented:** supported by a current primary source but not exercised in the reference apps.
- **Compiled:** passed an unsigned build or Simulator test.
- **Development-device verified:** installed and observed on a physical device with Development signing.
- **TestFlight verified:** processed, installed, and observed through TestFlight.
- **App Store verified:** released through the owner's store record.
- **Negative result:** reproduced failure that rules out a proposed default.

Record the date, locked tool versions, source revision, Apple channel, exact evidence, and remaining device/manual checks. Move transient UI gestures and one-off recovery steps to issue history, not this ledger.

Keep historical proof separate from current repository support. A successful command on an unmerged experiment branch may justify a design, but an owner cannot rely on it until the command and configuration exist in the checked-out revision.

## Verified reference findings — July 2026

| Finding | Evidence | Status |
| --- | --- | --- |
| One conventional Xcode project can support GUI, CLI, CI, physical-device, and TestFlight workflows | Photogram Golden and Dunbar150 reference apps | Development-device and TestFlight verified |
| A pinned XcodeGen spec plus committed project can give reviewable generation and zero-setup Xcode opening | Dunbar150 headless-tooling experiment | Compiled; CI drift check verified |
| `xcodebuild` plus `devicectl` can build, install, and launch on a paired iPhone without opening Xcode | Dunbar150 `bin/ios device` experiment | Development-device verified |
| GitHub-hosted macOS can build, sign, verify, and upload the real project | Photogram Golden clean-runner builds | TestFlight upload/processing verified |
| Xcode-installed tokens are Sandbox while TestFlight tokens are Production; routing must be per device | Photogram push migration | Sandbox physical receipt and server contract verified; full TestFlight receipt matrix remains pending |
| API-key-only automatic provisioning on disposable runners can leave orphaned account-side certificates | Two clean Photogram runner experiments | Negative result reproduced twice |
| A separate preview wrapper/Swift Playground creates drift and lacks the shipping entitlement surface | iPad Playground comparison | Negative architecture result |

Public evidence checkpoints:

- <https://github.com/firstdraft/photogram-golden/pull/29>
- <https://github.com/raghubetina/dunbar150/pull/20>
- <https://github.com/firstdraft/photogram-golden/actions/runs/29161173152>
- <https://github.com/firstdraft/photogram-golden/actions/runs/29161617000>

## Still unproved; do not present as the happy path

- A deliberately reduced-entitlement Personal Team configuration on an actually unpaid Apple account.
- The full owner-controlled GitHub Actions signing flow using a reusable `.p12` and profile, from clean setup through TestFlight install.
- Owner Staging and Production lanes exercised end to end with distinct identities, Associated Domains, and APNs.
- External TestFlight beta review and learner invitation at repeatable workshop scale.
- Public App Store submission and ownership handoff from a managed preview.
- The complete Production push matrix: foreground, background, terminated receipt, and warm/cold tap routing.

When one of these becomes proven, record the exact artifact and acceptance check before promoting it into the main workflow.
