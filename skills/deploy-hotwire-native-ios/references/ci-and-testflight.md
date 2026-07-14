# CI and TestFlight

Make pull-request evidence cheap, then isolate the credentials required for distribution.

## Run unsigned CI first

On pull requests, use a pinned macOS/Xcode environment to:

- resolve only locked Swift packages;
- regenerate/check project metadata when applicable;
- run unit/UI tests at the locked deployment floor;
- compile the Release configuration with signing disabled;
- preserve logs and artifacts needed to diagnose failure.

Unsigned Release compilation proves code, resources, package resolution, and app-icon compilation. It does not prove signing identity, provisioning, final entitlements, TestFlight processing, or device behavior.

## Protect the signed lane

For owner-controlled GitHub Actions:

- start signed releases with `workflow_dispatch` from an allowed protected branch or exact approved SHA;
- inspect repository visibility and the owner's GitHub plan before relying on environment secrets or required
  reviewers. A manual dispatch is an intentional start, not automatically a second-person approval gate, and
  private-repository environment protections vary by plan;
- pin third-party actions to full commit SHAs;
- disable persisted checkout credentials unless a job explicitly needs to push;
- store reusable signing material and upload credentials as secrets;
- import the `.p12` into a temporary keychain and install the matching profile;
- prevent fork or untrusted pull-request code from reaching the secret-bearing job;
- delete temporary files even on failure;
- verify the final IPA before upload.

A called reusable workflow still runs against caller-controlled source. It centralizes YAML; it does not make
organization secrets safe from malicious build phases. Never use `pull_request_target` or a privileged
`workflow_run` to check out and execute the untrusted pull-request head with secrets. Xcode builds may execute Run
Script phases, package plugins, and project generators even when code signing is disabled.

Use disposable, secret-free compute for untrusted revisions. Review build phases and plugins, approve one immutable
source SHA, and rebuild that SHA in the trusted signing lane. Do not sign an arbitrary artifact uploaded by a pull
request job. A persistent self-hosted Mac must not alternate between untrusted builds and trusted signing without a
real isolation/reset boundary; prefer an ephemeral VM or dedicated trusted runner.

GitHub-hosted macOS runners are ephemeral clean VMs. That does not make API-key-only automatic provisioning stateless: a runner can create an account-side certificate whose private key disappears with the VM. Prefer reusable signing material until an alternative certificate lifecycle is explicitly proved and cleaned up.

Xcode Cloud is an owner-controlled alternative when the owner has a paid Apple team. Keep the repository's unsigned CI and project scripts useful so Xcode Cloud is a choice rather than the only build surface.

## Keep automation credentials narrow

App Store Connect API keys authenticate API and upload operations. They are not the code-signing private key and not the APNs key used by Rails.

Team API keys inherit a role across the provider's App Store Connect account and cannot be limited to one app.
Individual API keys inherit that user's app access but do not support provisioning endpoints. A Developer can
normally upload builds, while creating distribution certificates requires Account Holder or Admin authority. Keep
high-privilege bootstrap/provisioning access separate from routine upload access, and confirm current role support
for every endpoint before creating a key.

An API key passed to Fastlane upload does not automatically authenticate an earlier `xcodebuild` archive/export. If automatic provisioning is required, pass the installed Xcode's documented authentication inputs to the phases that need them or make certificate/profile selection explicit.

## Keep Fastlane a pinned wrapper

If using Fastlane:

- lock it through Bundler in the native directory;
- invoke it from the directory that owns `fastlane/`;
- preflight required secret references, a clean/approved source revision, and a positive build number greater than
  the latest App Store Connect build for that marketing version;
- keep raw `xcodebuild` output available;
- prevent successful lanes from overwriting maintained documentation;
- inspect the exported IPA before `upload_to_testflight`.

Do not install a global floating Fastlane as the only documented path.

## Stage TestFlight deliberately

1. Record source SHA/dirty state, archive/export configuration, artifact SHA-256, certificate fingerprint, profile
   UUID/expiration, tool versions, and the approved build number. Refuse an ordinary release from dirty source;
   proceed only when the owner explicitly accepts the exception and the report records it.
2. Upload one monotonic build and wait for App Store Connect processing.
3. Resolve export-compliance metadata as a product/legal decision. Do not assume every dependency is exempt.
4. Prove an internal TestFlight install first.
5. Supply review credentials and test information for signed-in apps before external beta review.
6. Verify launch, authentication, production APNs registration/receipt, Associated Domains, and release-only server
   configuration on the TestFlight build.

TestFlight builds currently expire after 90 days. Internal testers are App Store Connect users; external testers may require beta review. Verify current limits and roles before automating invitations.

Primary references:

- <https://docs.github.com/en/actions/reference/runners/github-hosted-runners>
- <https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets>
- <https://docs.github.com/en/actions/reference/security/secure-use>
- <https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments>
- <https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target>
- <https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api>
- <https://developer.apple.com/help/account/certificates/certificates-overview/>
- <https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/>
- <https://docs.fastlane.tools/actions/pilot/>
