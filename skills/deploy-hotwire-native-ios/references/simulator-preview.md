# Simulator preview

Use a local or hosted iOS Simulator when the question does not require Apple signing or physical-device behavior. A
Simulator controlled through a browser is still a Simulator; it is not the ordinary Browser lane and does not raise
the evidence level to a signed device.

## Keep the runtime contract in the canonical app

Implementation of the Rails-root resolver belongs to `develop-hotwire-native`; this deployment workflow audits its
evidence and packages the resulting app. If that sibling Skill is absent, report the missing handoff rather than
implementing product behavior here. Build the ordinary source-owned Xcode project and do not create a second preview
shell. The Debug app may accept one per-launch Rails-origin environment variable or launch argument, provided the
application:

- keeps a baked HTTPS root as the default;
- validates an absolute host root and rejects credentials, non-root paths, queries, and fragments;
- permits HTTP only for loopback development;
- defines environment/argument precedence and does not persist the override;
- derives tab, authentication, and remote-configuration URLs from the selected root; and
- compiles the override out of Release behavior.

Keep secrets out of the URL. A temporary preview must be reachable from the Simulator executor over HTTPS and must
pass the Rails host, cookie, CSP, and authentication policies that the app actually enforces.

## Build one portable artifact

Keep unsigned Release compilation in the quality gate, then build a separate Debug artifact for preview. On a
pinned GitHub-hosted macOS/Xcode pair, use the locked Swift package graph and a generic Simulator destination:

```sh
xcodebuild build \
  -project path/to/App.xcodeproj \
  -scheme App \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$RUNNER_TEMP/DerivedData" \
  -onlyUsePackageVersionsFromResolvedFile \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

Adapt project/workspace and scheme arguments to the target. Record the actual Xcode version instead of treating the
example as a floating toolchain selection. If a dependency cannot build both architectures, stop and make the
executor compatibility decision explicit rather than silently publishing a machine-specific artifact.

Stamp the baked Rails origin and full source revision into non-secret app metadata. Build from the approved clean
revision, confirm the output platform is `iphonesimulator`, and package exactly one top-level `.app` while preserving
the bundle:

```sh
ditto -c -k --keepParent path/to/App.app "$RUNNER_TEMP/App.app.zip"

ruby <skill-dir>/scripts/inspect_artifact.rb \
  --json \
  --expect-unsigned \
  --expect-platform iphonesimulator \
  --expect-architecture arm64 \
  --expect-architecture x86_64 \
  --source-root . \
  --expect-clean-source \
  --expect-source-sha "$(git rev-parse HEAD)" \
  "$RUNNER_TEMP/App.app.zip" > "$RUNNER_TEMP/App.app.inspection.json"
```

The inspection report records the archive digest, embedded source, platform, and each embedded executable's path,
digest, and architectures. The architecture gate applies to the main app, nested apps, extensions, frameworks, XPC
services, and standalone dynamic libraries; every reported executable must contain every requested slice. Xcode may
linker-sign a Simulator executable ad hoc even when Apple code signing is disabled; `--expect-unsigned` accepts an
explicit linker signature only when there is no Apple team identity or provisioning profile. Every ordinary present
signature must verify, and the credential-free check covers nested bundles and standalone dynamic libraries. It
rejects an identity-signed code object. Upload the zip and report as short-lived CI artifacts. Do not commit the app,
zip, report, or DerivedData. Use a read-only checkout, pin actions to immutable revisions, and keep Apple and
hosted-Simulator credentials out of the job.

## Hand off without coupling to a provider

Download the reviewed artifact, give the chosen hosted Simulator that unchanged zip through its user-authenticated
surface, and supply the Rails origin only for the launch. One native build may then exercise multiple Rails previews;
a native source change still requires a new artifact.

An owner may source-control a narrow provider adapter at the repository edge. Keep it optional and replaceable: it
may pass the canonical zip, digest, and per-launch inputs to one documented provider API, but it must not alter the
artifact, become a prerequisite for building the app, or move provider credentials into source control or CI. The
application may expose that adapter through an explicit `bin/ios preview <provider>` namespace with start, status,
and stop operations. Keep the provider-specific implementation behind that namespace so changing providers does not
change the portable artifact contract. This generic Skill defines the boundary but does not implement a provider API.

Record the artifact digest, source SHA, hosted runtime/device, per-launch origin, and observed navigation. Confirm the
selected origin through target-server requests or another end-to-end observation; the artifact report proves its
baked default, not the runtime argument chosen later.

Keep provider account policy, artifact admission, retention, session orchestration, and device inventory out of the
application build contract and this Skill. The app-side contract ends at the inspected artifact, launch inputs, and
observable result.

## State the proof boundary

A successful hosted-Simulator smoke test can prove that the canonical shell launches, selects the requested Rails
origin, authenticates, navigates, and integrates web/native behavior supported by Simulator. It does not prove code
signing, provisioning, Associated Domains, Shared Web Credentials, APNs receipt, camera or other hardware, process
lifecycle on a physical device, TestFlight, or App Store distribution.

Primary references:

- <https://developer.apple.com/documentation/xcode/xcode-command-line-tool-reference>
- <https://docs.github.com/en/actions/reference/runners/github-hosted-runners>
- <https://github.com/actions/upload-artifact>
