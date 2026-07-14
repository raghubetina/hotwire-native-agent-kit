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

- use protected environments and manual dispatch/approval for releases;
- pin third-party actions to full commit SHAs;
- store reusable signing material and upload credentials as secrets;
- import the `.p12` into a temporary keychain and install the matching profile;
- prevent fork/untrusted pull-request code from reaching the secret-bearing job;
- delete temporary files even on failure;
- verify the final IPA before upload.

A called reusable workflow still runs against caller-controlled source. It centralizes YAML; it does not make organization secrets safe from malicious build phases.

GitHub-hosted macOS runners are ephemeral clean VMs. That does not make API-key-only automatic provisioning stateless: a runner can create an account-side certificate whose private key disappears with the VM. Prefer reusable signing material until an alternative certificate lifecycle is explicitly proved and cleaned up.

Xcode Cloud is an owner-controlled alternative when the owner has a paid Apple team. Keep the repository's unsigned CI and project scripts useful so Xcode Cloud is a choice rather than the only build surface.

## Keep automation credentials narrow

App Store Connect API keys authenticate API and upload operations. They are not the code-signing private key and not the APNs key used by Rails.

Check the key role for each operation. A Developer role can upload but may not create missing provisioning resources. Keep higher-privilege provisioning/bootstrap access separate from routine upload access when possible.

An API key passed to Fastlane upload does not automatically authenticate an earlier `xcodebuild` archive/export. If automatic provisioning is required, pass the installed Xcode's documented authentication inputs to the phases that need them or make certificate/profile selection explicit.

## Keep Fastlane a pinned wrapper

If using Fastlane:

- lock it through Bundler in the native directory;
- invoke it from the directory that owns `fastlane/`;
- preflight required environment variables and positive build number;
- keep raw `xcodebuild` output available;
- prevent successful lanes from overwriting maintained documentation;
- inspect the exported IPA before `upload_to_testflight`.

Do not install a global floating Fastlane as the only documented path.

## Stage TestFlight deliberately

1. Upload one monotonic build and wait for App Store Connect processing.
2. Resolve export-compliance metadata as a product/legal decision. Do not assume every dependency is exempt.
3. Prove an internal TestFlight install first.
4. Supply review credentials and test information for signed-in apps before external beta review.
5. Verify launch, authentication, production APNs registration/receipt, Associated Domains, and release-only server configuration on the TestFlight build.

TestFlight builds currently expire after 90 days. Internal testers are App Store Connect users; external testers may require beta review. Verify current limits and roles before automating invitations.

Primary references:

- <https://docs.github.com/en/actions/reference/runners/github-hosted-runners>
- <https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets>
- <https://docs.github.com/en/actions/reference/security/secure-use>
- <https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api>
- <https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/>
- <https://docs.fastlane.tools/actions/pilot/>
