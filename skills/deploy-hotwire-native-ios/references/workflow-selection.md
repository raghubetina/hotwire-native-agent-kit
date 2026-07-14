# Workflow selection

Choose the evidence required before choosing the most expensive account or distribution path.

## Separate the five decisions

Record these independently:

1. **Source owner** — who controls the repository and release revision?
2. **Apple-team owner** — whose legal account owns the App ID and store record?
3. **Build machine** — local Mac, GitHub-hosted macOS, Xcode Cloud, or another controlled Mac running the supported
   Xcode toolchain?
4. **Rails origin** — local Development, owner Staging, owner Production, or a temporary preview deployment?
5. **Install channel** — Simulator, direct device, Ad Hoc registered-device distribution, TestFlight, or App Store?

Moving Xcode into the cloud changes decision 3. It does not remove the Apple-account requirements of decisions 2 and 5.

## Choose the smallest sufficient path

| Path | Apple membership | What it proves | Important limit |
| --- | --- | --- | --- |
| Browser | None | Rails product and responsive UI | No native shell or device capability |
| iOS Simulator | None | Native compilation, navigation, and most web/native integration | No production signing or physical-device proof |
| Direct device with Personal Team | Free Apple account | Short-lived development install on the owner's phone | No TestFlight; Push and Associated Domains are unavailable |
| Direct device with paid team | Apple Developer Program | Development signing and Sandbox capabilities | Still not Production signing or TestFlight packaging |
| Ad Hoc | Paid team | Production-signed IPA installed on registered device UDIDs | Requires Apple Distribution signing and an Ad Hoc profile; device and annual limits apply |
| Internal TestFlight | Paid team | Production-signed beta packaging for App Store Connect users | Build expires; internal users have team access |
| External TestFlight | Paid team | Production-signed beta for invited external testers | Beta review may be required; builds expire after 90 days |
| App Store | Paid team | Public or private store distribution | Review, product metadata, legal, and ownership obligations apply |

Apple currently documents free Personal Team limits of 10 App IDs, 3 registered devices, 3 installed apps per device, and 7-day expiration for App IDs, devices, and profiles. Treat those numbers as date-sensitive and verify them before presenting them to a user.

Do not configure a free Personal Team against the production target when that target declares unsupported Push Notifications or Associated Domains. A free workshop path needs an intentionally reduced-entitlement Development configuration and its own acceptance test.

## Match the channel to the question

- Use Browser and Simulator for the fast inner loop.
- Use a directly installed Development build for Developer Mode, cookies across process death, password AutoFill,
  camera behavior, Universal Links, and Sandbox APNs.
- Use Ad Hoc only when registered-device installation without TestFlight materially helps the owner. It adds
  production signing and UDID/profile management, so it is not the default workshop path.
- Use TestFlight for Production APNs, store packaging, beta installation, and release-only configuration.
- Use App Store review only when the owner actually intends to publish.

An app uploaded to App Store Connect but never installed through TestFlight has not passed the beta-user path. A device row in Rails has not proved APNs delivery.

## Preserve ownership during assisted previews

A school, agency, or workshop provider may offer a time-limited TestFlight preview under its own Apple team. Keep that boundary visible:

- the owner retains the conventional Xcode source and unsigned CI;
- the provider's credentials never enter the owner's repository or runner;
- the preview's bundle ID, APNs credentials, and store record belong to the provider;
- graduation means configuring the owner's team and globally unique bundle ID, then rebuilding every team-bound contract;
- do not promise that a TestFlight-only app can be transferred.

Provider-side credential custody, signing policy, and tester operations are outside this Skill.

Primary references:

- <https://developer.apple.com/help/account/basics/about-your-developer-account/>
- <https://developer.apple.com/help/account/reference/supported-capabilities-ios/>
- <https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/>
