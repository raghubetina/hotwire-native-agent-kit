# Project and environments

Keep one source-owned Xcode project capable of producing every owner lane.

## Audit the canonical project

Record:

- project/workspace path, app scheme, and application/test targets;
- Xcode and iOS deployment targets;
- exact Swift package versions and committed `Package.resolved`;
- project generator and its pinned version, if present;
- Debug/Release or Development/Staging/Production configurations;
- checked-in versus local-only `.xcconfig` files;
- command wrappers and CI entry points.

Start with the bundled read-only inventory, then verify its findings against the project rather than treating text
search as build-system truth:

```sh
ruby <skill-dir>/scripts/audit_project.rb --root . --json
```

For a release candidate, add the expected bundle ID, team, Rails origin, and `--expect-clean-source`. The command
does not contact Apple, change project files, or unlock a keychain.

Keep the app and all test targets on the intended deployment floor. Add Push Notifications and Associated Domains to the application target, not to unit- or UI-test targets.

## Keep project generation reviewable

XcodeGen can make project metadata deterministic when its YAML/JSON spec is reviewable. If used:

- pin XcodeGen and verify the downloaded release checksum;
- treat the spec as the source of truth;
- commit the generated `.xcodeproj` so a fresh checkout still opens without setup;
- regenerate in a temporary copy during CI and reject drift;
- retain shared schemes and locked Swift packages.

XcodeGen manages project metadata. It does not manage certificates, private keys, registered devices, or provisioning profiles.

Avoid a second Swift Playground or generic wrapper solely for preview. It can drift from the shipping target and may not expose the same entitlement surface.

## Model environment lanes deliberately

Prefer one source target with configuration-driven values:

| Lane | Rails origin | Identity | Signing |
| --- | --- | --- | --- |
| Development | localhost, LAN/tunnel, or explicit developer server | visibly non-production bundle/name when practical | unsigned Simulator or Development profile |
| Hosted Simulator preview | reachable temporary HTTPS origin selected per launch | source-owned Debug identity | unsigned Simulator artifact |
| Staging | stable owner-controlled HTTPS origin | distinct bundle ID/name/icon | owner-controlled Development/Distribution assets |
| Production | final public HTTPS origin | final bundle ID and display identity | owner Distribution profile |
| Managed signed preview | explicit temporary origin and provider identity | provider-owned bundle ID | external provider contract |

Treat the per-launch Rails-root resolver as application behavior owned by `develop-hotwire-native`. This deployment
workflow verifies the resulting contract instead of implementing it: the override is Debug-only, validated,
non-persistent, and ignored by Release, while the baked default remains explicit. If the sibling Skill is absent,
report that handoff. Do not let Run-scheme localhost values leak into ordinary tests or archives. Tests should
exercise the baked default unless they explicitly own a server fixture. Read [simulator-preview.md](simulator-preview.md)
when producing the portable artifact.

Stamp the resolved release origin and source revision into non-secret `Info.plist` keys such as `RailsOrigin` and
`SourceRevision` for Staging and Production artifacts. That lets the exported artifact prove what it will open and
which approved commit it came from without reverse-engineering compiled Swift strings. Keep the runtime constant
and stamped metadata derived from the same configuration values, and test that they agree.

The Simulator reaches the Mac's `localhost`. A physical iPhone does not; use a reachable LAN address, an owner-controlled tunnel, Staging, or Production.

Before archiving Staging or Production, reject:

- `.invalid`, localhost, or placeholder origins;
- missing/placeholder team IDs and bundle IDs;
- a Staging binary that silently uses Production identity;
- release builds with debug inspection or arbitrary server overrides enabled.

## Give humans and agents one front door

A thin repository wrapper such as `bin/ios` should expose the real commands without swallowing diagnostics. Keep it
at the application root as the source-owned front door contributed and maintained by the iOS capability, even when
the Xcode project and implementation scripts live under `ios/`:

```text
doctor
generate / check-project
test
simulator
simulator-artifact
device
archive / beta
preview PROVIDER / preview PROVIDER status / preview PROVIDER stop (optional adapter)
```

The wrapper may select full Xcode, bootstrap Simulator state, build a portable artifact, and locate outputs. Keep
`xcodebuild`, `simctl`, and `devicectl` failures visible. It may also route optional preview lifecycle commands to a
narrow, replaceable provider adapter, provided that adapter consumes the unchanged canonical artifact and keeps
credentials out of source control and CI. Keep provider-specific implementation isolated from the build commands.
On a trusted checkout, run `bin/ios help` before suggesting a command and use provider-neutral and provider-specific
doctor commands at their corresponding boundaries. Ask the installed tools for current syntax with
`xcodebuild -help` and `xcrun devicectl help` rather than freezing undocumented flags forever.

Primary references:

- <https://developer.apple.com/documentation/xcode/xcode-command-line-tool-reference>
- <https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices>
- <https://github.com/yonaskolb/XcodeGen>
- <https://yonaskolb.github.io/XcodeGen/Docs/ProjectSpec.html>
