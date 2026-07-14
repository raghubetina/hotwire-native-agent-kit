---
name: deploy-hotwire-native-ios
description: Prepare, build, sign, verify, and distribute owner-controlled Hotwire Native iOS applications. Use for choosing Simulator, direct-device, Personal Team, TestFlight, or App Store paths; configuring Development, Staging, and Production lanes; driving Xcode or Xcode command-line tools; managing bundle IDs, certificates, profiles, entitlements, App Store Connect keys, GitHub Actions, Xcode Cloud, XcodeGen, or Fastlane; verifying APNs and Associated Domains in signed artifacts; handing off from a managed preview to the owner's Apple team; or diagnosing iOS signing, provisioning, archive, export, and upload failures.
---

# Deploy Hotwire Native iOS

Keep the Xcode project, Apple account, build machine, signing identity, server environment, and distribution channel explicit. They are related, but they are not the same choice.

## Follow the workflow

1. Read [workflow-selection.md](references/workflow-selection.md). Record who owns the source and Apple team, where Xcode runs, which Rails environment the binary opens, which channel installs it, and which device capability must be proved.
2. Inspect the repository before changing it:
   - Xcode project/workspace, shared schemes, configurations, deployment floors, and locked Swift packages;
   - bundle-ID family, display names, team settings, entitlements, AASA hosts, APNs topic, and build number;
   - project generator, command wrappers, Fastlane/Bundler inputs, and CI workflows;
   - application-owned Development, Staging, Production, and optional preview configuration.
3. Read only the task-specific references below. Check current Apple/provider documentation and the installed Xcode help before freezing version-sensitive commands.
4. Make the smallest reproducible change. Preserve one canonical source-owned Xcode project and keep account-specific secrets outside it.
5. Run unsigned compilation/tests first when they can fail before signing. Then run the channel-specific archive, export, or install path.
6. Inspect the final signed `.app` or IPA. Do not infer its identity and capabilities from source settings.
7. Test at the layer that proves the claim: browser, Simulator, Xcode-installed device, TestFlight, or App Store.
8. Report the exact lane, source revision, toolchain, Apple team, bundle ID, Rails origin, artifact checks, device checks, and any steps not run.

## Enforce these gates

- Xcode must run on macOS somewhere; Xcode's GUI does not have to be the ordinary interface.
- Do not ask for a paid account when Simulator evidence is sufficient. Do not promise TestFlight, App Store, Push Notifications, or Associated Domains from a free Personal Team.
- Keep Development server overrides Debug-only. Bake Staging and Production origins into their archives and reject placeholders before export.
- Use one ordinary Xcode project for local, CI, and store builds. Do not maintain a parallel Swift Playground or generic preview shell as a second source of truth.
- Claim current support only for commands, configuration, and workflows reachable from the checked-out revision. Treat documentation, closed PRs, and experiment branches as evidence to inspect, not features the owner can run now.
- Never commit certificates, private keys, provisioning profiles, APNs keys, or App Store Connect keys. Base64 is transport encoding, not encryption.
- Never run untrusted repository code in a job that holds another organization's signing credentials. A reusable workflow is not a security boundary by itself.
- Treat distribution signing material, App Store Connect API keys, and APNs provider keys as three different secret classes.
- Persist and route APNs Sandbox versus Production per registered device. A Rails-environment or deployment-wide switch cannot safely serve Xcode and TestFlight installations together.
- Preserve raw `xcodebuild` output when diagnosing provisioning. Compact formatters must not hide the target-level failure.
- Do not call an upload, token row, provider response, or Simulator run “device verified.” Require physical-device observation for OS-mediated behavior.
- Keep Rails/native product implementation, Bridge Components, navigation, and push-registration lifecycle in `develop-hotwire-native`. This Skill verifies that deployment preserves and exercises those contracts.
- Do not operate a managed-signing provider's credential store, artifact ingestion, policy engine, uploader, or tester administration from this Skill. Limit work to the owned app and its documented handoff contract.

## Route the task

| Task | Read |
| --- | --- |
| Choose a build, account, device, and distribution path | [workflow-selection.md](references/workflow-selection.md) |
| Configure canonical project metadata and environment lanes | [project-and-environments.md](references/project-and-environments.md) |
| Manage signing identities, profiles, capabilities, AASA, and APNs | [signing-and-capabilities.md](references/signing-and-capabilities.md) |
| Build on CI and upload through TestFlight/App Store Connect | [ci-and-testflight.md](references/ci-and-testflight.md) |
| Diagnose archive, export, provisioning, and delivery failures | [troubleshooting.md](references/troubleshooting.md) |
| Distinguish proven workflow from a proposed default | [evidence-ledger.md](references/evidence-ledger.md) |

## Use proof-specific language

| Claim | Minimum evidence |
| --- | --- |
| The web product works | Browser/request/system tests |
| The native shell compiles | Unsigned Simulator or generic-device build |
| Development signing works | Xcode-installed build on a paired physical device |
| Entitlements are present | Inspection of the final signed app and embedded profile |
| Universal Links work | OS-mediated link from outside the app on a signed device |
| Production push works | TestFlight/App Store token, provider acceptance, and physical receipt |
| TestFlight works | Processed build installed and launched through TestFlight |

An earlier layer may be a useful checkpoint, but it does not prove a later claim.

## Finish with an owner-controlled exit path

The repository should remain buildable without the organization that originally previewed or generated it. A managed preview may add a temporary signing overlay, but the source, project definition, environment model, unsigned CI, and owner-run distribution instructions stay in the application repository.
