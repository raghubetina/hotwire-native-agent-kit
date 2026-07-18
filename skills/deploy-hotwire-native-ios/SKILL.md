---
name: deploy-hotwire-native-ios
description: Audit and operate owner-controlled Hotwire Native iOS build and distribution paths. Use for discovering which preview or deployment lanes are feasible from the current Mac, Windows, Linux, Codespace, VM, or CI executor; choosing local or hosted Simulator, direct-device, Ad Hoc, TestFlight, or App Store paths; building portable unsigned Simulator artifacts; configuring Development, Staging, and Production lanes; driving Xcode or its command-line tools; managing bundle IDs, certificates, profiles, entitlements, App Store Connect keys, GitHub Actions, Xcode Cloud, XcodeGen, or Fastlane; verifying APNs and Associated Domains in signed artifacts; handing off from a managed preview to the owner's Apple team; or diagnosing signing, provisioning, archive, export, and upload failures.
---

# Deploy Hotwire Native iOS

Keep the Xcode project, Apple account, build machine, signing identity, Rails environment, and distribution channel explicit. They are related, but they are not the same choice. Default to a read-only audit and the cheapest proof that answers the owner's question.

## Follow the workflow

1. Run `ruby <skill-dir>/scripts/audit_project.rb --root <project-root>` and read
   [workflow-selection.md](references/workflow-selection.md). Discover the current executor and the trusted
   repository's own command surface before recommending a lane. Record who owns the source and Apple team, where
   the Apple-supported Xcode toolchain runs, which Rails origin the binary opens, which channel installs it, and
   which device capability must be proved.
2. Inspect the canonical project, shared schemes, configurations, deployment floors, locked packages, bundle-ID
   family, entitlements, build numbers, command wrappers, Fastlane/Bundler inputs, and CI workflows.
3. Choose a lane and load its ordered reference set below. Check current primary documentation and installed-tool
   help before freezing date-sensitive limits or version-sensitive commands.
4. Separate audit from mutation. Inventory current Apple resources and dependencies, state the exact external
   change, and obtain the owner's approval before changing account state or distributing a build.
5. Make the smallest reproducible source change. Keep account secrets outside the repository. Compile and test
   unsigned first when that can fail before signing.
6. Rebuild the approved source revision in the trusted lane. Inspect the exported `.app`, `.app.zip`, `.ipa`, or `.xcarchive`
   with `inspect_artifact.rb`; never infer identity or capabilities from project settings or upload success.
7. Test at the layer that proves the claim: browser, Simulator, Xcode-installed device, Ad Hoc install, TestFlight,
   or App Store. Record physical receipt for OS-mediated behavior.
8. Report the lane, source SHA and dirty state, toolchain, Apple team, bundle ID, Rails origin, provisioning channel, artifact digest,
   signature/profile/entitlement checks, device observations, approvals, and checks not run.

## Require approval for external changes

Do not create, rotate, or revoke App IDs, capabilities, certificates, profiles, devices, API keys, or APNs keys;
upload a build; assign testers; submit for beta or App Store review; or release an app without explicit owner
approval for that exact action. Before revocation, record certificate fingerprints, profile dependencies, and the
replacement/rollback plan.

Never ask the owner to paste a private key or password into chat. Never print secret values. Work with secret
references, public IDs, fingerprints, and redacted command output. Treat app-signing material, App Store Connect
automation keys, and APNs provider keys as separate secret classes with separate owners and lifecycles.

## Enforce these gates

- The supported path uses Apple's Xcode toolchain on macOS somewhere; its GUI need not be the daily interface.
  Cross-platform reverse-engineered toolchains are outside the happy path and require an explicit request plus
  separate validation against Apple's current terms and the target capability set.
- Do not request a paid account when Browser or Simulator evidence is sufficient. Do not promise TestFlight, App
  Store, Push Notifications, or Associated Domains from a free Personal Team.
- Keep Development server overrides Debug-only. Bake Staging and Production origins into their archives and reject
  placeholders before export.
- Keep one ordinary source-owned Xcode project for local, CI, and store builds. Do not maintain a parallel Swift
  Playground or generic preview shell as a second source of truth.
- Claim current support only for workflows reachable from the checked-out revision. Read
  [support-status.md](references/support-status.md) before presenting an advisory path as proven.
- Never commit certificates, private keys, provisioning profiles, APNs keys, or App Store Connect keys. Base64 is
  transport encoding, not encryption.
- Never commit DerivedData, built `.app`/`.app.zip` artifacts, or artifact reports. Produce them in an ignored build
  directory or runner-temporary directory and publish them with deliberate, short retention.
- Never execute untrusted repository code on a machine or job holding signing credentials. Reusable workflows,
  persistent self-hosted runners, and `pull_request_target` do not create a trust boundary.
- Persist APNs Sandbox versus Production beside each registered device. A global or Rails-environment switch cannot
  safely serve Xcode and TestFlight installations together.
- Preserve raw `xcodebuild` output when diagnosing provisioning. Compact formatters must not hide target failures.
- Do not call an upload, token row, provider response, or Simulator run “device verified.” Require physical-device
  observation for OS-mediated behavior.
- Keep Rails/native product behavior in `develop-hotwire-native`. If that independently installed Skill is absent,
  report the missing handoff instead of improvising product implementation here.
- Keep a managed-signing provider's credential store, artifact admission, policy engine, uploader, and tester
  administration outside this public Skill.

## Route by deployment lane

| Lane | Read in order |
| --- | --- |
| Audit or choose a path | [workflow-selection.md](references/workflow-selection.md), [project-and-environments.md](references/project-and-environments.md), [support-status.md](references/support-status.md) |
| Local or hosted Simulator | [workflow-selection.md](references/workflow-selection.md), [project-and-environments.md](references/project-and-environments.md), [simulator-preview.md](references/simulator-preview.md) |
| Direct device | [workflow-selection.md](references/workflow-selection.md), [project-and-environments.md](references/project-and-environments.md), [signing-and-capabilities.md](references/signing-and-capabilities.md), [direct-device.md](references/direct-device.md) |
| Ad Hoc | [workflow-selection.md](references/workflow-selection.md), [project-and-environments.md](references/project-and-environments.md), [signing-and-capabilities.md](references/signing-and-capabilities.md), [ad-hoc.md](references/ad-hoc.md) |
| TestFlight | [workflow-selection.md](references/workflow-selection.md), [project-and-environments.md](references/project-and-environments.md), [signing-and-capabilities.md](references/signing-and-capabilities.md), [ci-and-testflight.md](references/ci-and-testflight.md), [support-status.md](references/support-status.md) |
| App Store readiness or handoff | TestFlight set, then [app-store-handoff.md](references/app-store-handoff.md) |
| Diagnose a failure | The chosen lane's set, then [troubleshooting.md](references/troubleshooting.md) |

## Use proof-specific language

| Claim | Minimum evidence |
| --- | --- |
| The web product works | Browser/request/system tests |
| The native shell compiles | Unsigned Simulator or generic-device build |
| A portable Simulator artifact is valid | Inspected unsigned `iphonesimulator` app archive whose main and embedded executables carry every required architecture, source revision, and digest |
| A hosted Simulator preview works | That exact artifact launched against the intended Rails origin and completed the target navigation smoke test |
| Development signing works | Xcode-installed build on a paired physical device |
| Ad Hoc packaging works | Production-signed build installed on a registered device |
| Entitlements are present | Inspection of every final signed app/extension and embedded profile |
| Universal Links work | OS-mediated link from outside the app on a signed device |
| Production push works | Production token, provider acceptance, and physical receipt |
| TestFlight works | Processed build installed and launched through TestFlight |
| App Store release works | Approved version installed from its App Store record |

An earlier layer may be a useful checkpoint, but it does not prove a later claim.

## Finish with an owner-controlled exit path

The repository must remain buildable without the organization that originally previewed or generated it. A managed
preview may add a temporary signing overlay, but the source, project definition, environment model, unsigned CI,
and owner-run distribution instructions stay in the application repository.
