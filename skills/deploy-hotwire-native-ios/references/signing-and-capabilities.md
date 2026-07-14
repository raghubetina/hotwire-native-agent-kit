# Signing and capabilities

Signing is an identity contract, not the final build command.

## Keep the identity tuple aligned

Verify the same application identity across:

- Apple team ID;
- globally unique bundle identifier;
- App ID and App Store Connect app record;
- signing certificate/private key and provisioning profile;
- `application-identifier` entitlement;
- APNs topic;
- Associated Domains entitlements and AASA application ID;
- Rails configuration and provider credentials.

A copied shell can compile while retaining the old app's identity in Fastlane, entitlements, tests, or server configuration. Search the entire Rails/native repository when renaming or transferring ownership.

## Distinguish the secret classes

1. **Distribution signing:** certificate plus private key and matching provisioning profile.
2. **App Store Connect automation:** issuer ID, Key ID, and `.p8` API key used for API/upload operations.
3. **APNs provider delivery:** a separate APNs key held by the Rails deployment.

One key does not replace the others. Do not commit any of them. Import CI signing material into a temporary keychain, limit access, and remove temporary files after use.

## Verify capabilities at three layers

For Push Notifications and Associated Domains, compare:

1. **Project request** — checked-in entitlements and target capabilities.
2. **Provisioning authorization** — embedded profile permits the capability for the exact team and bundle ID.
3. **Final signature** — signed app contains the exact entitlement values intended for this binary.

Inspect the final `.app` or IPA rather than trusting the source file or successful export. At minimum verify:

- Apple Distribution versus Development identity appropriate to the channel;
- exact `application-identifier` and team;
- `aps-environment=development` for Xcode installs or `production` for TestFlight/App Store;
- exact `applinks:` and `webcredentials:` values;
- embedded profile identity and expiration;
- final bundle ID, version, and positive monotonic build number.

## Keep Associated Domains three-sided

The signed entitlement, HTTPS host, and AASA document must agree. Serve AASA directly without a redirect from `/.well-known/apple-app-site-association`. Separate subdomains need their own association coverage.

Changing the team, bundle ID, or domain requires a new signed binary and matching server document. A browser `200` proves the file is reachable, not that iOS accepted the association.

## Route APNs by token environment

Development profiles produce Sandbox tokens. TestFlight and App Store builds produce Production tokens. Persist that environment beside each registered device and select the matching endpoint and environment-specific, topic-specific key for delivery.

Do not infer endpoint from `Rails.env`. Do not use one global Sandbox switch when Xcode and TestFlight installations may coexist. Verify provider acceptance and physical receipt; `BadDeviceToken` often signals an environment mismatch, while `DeviceTokenNotForTopic` points to the topic/app identity.

Primary references:

- <https://developer.apple.com/documentation/bundleresources/entitlements/aps-environment>
- <https://developer.apple.com/documentation/xcode/supporting-associated-domains>
- <https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns>
- <https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns>
