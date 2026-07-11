# Distribution and signing

Separate source ownership, the machine that builds, the Apple account that signs, and the channel that distributes.
Xcode must run on macOS somewhere, but that Mac may belong to the owner, CI, a build service, or Apple.

## Choose the path by owner and capability

- A free Personal Team can install development builds on a small number of registered devices, with short-lived
  signing. It does not provide TestFlight or App Store distribution.
- TestFlight and App Store distribution require an active Apple Developer Program membership for the team that owns
  the app, regardless of whether Xcode runs locally, on GitHub-hosted macOS, Xcode Cloud, or another Mac service.
- A service can build under the app owner's team using narrowly stored owner credentials, or under the service's
  team for a managed preview. Those are different ownership and handoff models; state which one applies.
- A TestFlight-only app is a time-limited preview. Do not promise permanent distribution or assume it can be
  transferred without checking Apple's current transfer criteria.

Do not replace the owned Hotwire Native source with a generic runtime driven only by JSON/YAML unless the product
explicitly accepts that constraint. A hosted browser preview can supplement the real project, not redefine it.

## Generate and verify owned projects

Prefer an ordinary source-owned Xcode project. XcodeGen can make project metadata deterministic when the generated
spec remains reviewable, but it does not replace Xcode, signing, or platform testing. Avoid maintaining a second
Swift Playground or parallel wrapper solely for workshop preview; it drifts from the shipping project and lacks
the full entitlement surface.

Pin Swift packages and Fastlane/Bundler inputs. Give each upload a monotonic build number. Before upload, inspect
the exported archive/IPA rather than trusting project settings:

- bundle/application identifier and Apple team;
- `aps-environment` and Push Notifications capability;
- Associated Domains and matching AASA application ID;
- minimum OS/device families and release-only transport policy;
- signing certificate and provisioning profile appropriate to the channel.

Keep App Store Connect API keys, distribution certificates/private keys, and APNs provider keys separate. Remove
temporary key/profile files from hosted runners even when the runner is ephemeral.

## Test at the layer that proves the claim

- A browser proves the Rails product.
- A simulator proves most shell navigation and layout, but not physical APNs receipt, real password AutoFill,
  camera behavior, or Universal Links launched from other apps.
- An Xcode-installed physical build proves development signing and Sandbox capabilities.
- TestFlight proves production signing, Production APNs registration, beta installation, and store packaging.

Automate tests, archive verification, upload, and tester assignment when APIs permit. Keep the remaining account-
holder steps in an explicit walkthrough or generated first-steps checklist rather than hiding them in tribal
knowledge.

Primary references:

- <https://developer.apple.com/help/account/keys/create-a-private-key/>
- <https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview>
- <https://developer.apple.com/xcode-cloud/>
