# Signing and capabilities

Signing is an identity contract, not the final build command.

## Keep the identity tuple aligned

Verify the same application identity across:

- Apple team ID;
- provisioning profile's Application Identifier Prefix, which can differ from the team ID for legacy or transferred
  apps;
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

One key does not replace the others. Do not commit any of them. Import CI signing material into a temporary
keychain, limit access, and remove temporary files after use.

For each credential, record only non-secret metadata: owner, purpose, team/app scope, public ID or certificate
fingerprint, creation/expiration date, storage location by secret reference, rotation plan, and dependent workflows.
Rotate with an overlap period and rollback path where Apple permits it. Revoke only after inventorying every profile,
runner, deployment, and provider that depends on the old identity. A suspected compromise requires immediate owner
escalation, revocation/rotation, build and device-token impact review, and audit-log preservation.

## Verify capabilities at three layers

For Push Notifications and Associated Domains, compare:

1. **Project request** — checked-in entitlements and target capabilities.
2. **Provisioning authorization** — embedded profile permits the capability for the exact team and bundle ID.
3. **Final signature** — signed app contains the exact entitlement values intended for this binary.

Treat the profile as an allowlist. The bundled inspector models application-identifier prefixes, team identifiers,
APNs, Associated Domains, app groups, keychain groups, `get-task-allow`, and beta-reporting authorization, including
wildcard and subset semantics. It fails closed and reports `unverified_entitlement_keys` when a signed artifact adds
an entitlement whose authorization semantics are not modeled yet; extend/review the verifier before claiming that
capability. The profile must also contain the leaf signing certificate used by the final signature. Inspect the
final `.app` or IPA rather than trusting the source file or successful export. At minimum verify:

- Apple Distribution versus Development identity appropriate to the channel;
- exact `application-identifier` and team;
- `aps-environment=development` for Development installs or `production` for Ad Hoc/TestFlight/App Store;
- exact `applinks:` and `webcredentials:` values;
- embedded profile identity and expiration;
- final bundle ID, version, and positive monotonic build number.

Use the bundled inspector for a redacted, machine-readable evidence report. Supply expectations from the approved
release plan rather than accepting whatever the artifact happens to contain:

```sh
ruby <skill-dir>/scripts/inspect_artifact.rb path/to/App.ipa \
  --source-root . \
  --expect-clean-source \
  --expect-source-sha "$APPROVED_SHA" \
  --expect-channel app-store-connect \
  --expect-bundle-id com.example.app \
  --expect-team-id ABCDE12345 \
  --expect-aps-environment production \
  --expect-associated-domain applinks:example.com \
  --json
```

`--expect-source-sha` requires the checkout and the artifact's non-secret `SourceRevision` metadata to match the
same full commit. If the app does not stamp that value, bind the artifact digest to source through a separately
verified build attestation rather than treating the current checkout as provenance.

Retain the report beside the release evidence, not secret material. Review every nested extension reported by the
tool; a valid main app does not excuse an extension signed by the wrong team or missing its authorized entitlements.

## Keep Associated Domains three-sided

The signed entitlement, HTTPS host, and AASA document must agree. Serve AASA directly without a redirect from `/.well-known/apple-app-site-association`. Separate subdomains need their own association coverage.

Changing the team, bundle ID, or domain requires a new signed binary and matching server document. A browser `200` proves the file is reachable, not that iOS accepted the association.

## Route APNs by token environment

Development profiles produce Sandbox tokens. Ad Hoc, TestFlight, and App Store builds produce Production tokens.
Persist that environment beside each registered device and select the matching APNs endpoint plus a provider key
authorized for the intended environment and topic. Choose team-scoped versus topic-scoped and environment-scoped
keys deliberately; do not assume every existing key has the same scope as a newly created key.

Do not infer endpoint from `Rails.env`. Do not use one global Sandbox switch when Xcode and TestFlight installations may coexist. Verify provider acceptance and physical receipt; `BadDeviceToken` often signals an environment mismatch, while `DeviceTokenNotForTopic` points to the topic/app identity.

Primary references:

- <https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles>
- <https://developer.apple.com/documentation/bundleresources/entitlements/aps-environment>
- <https://developer.apple.com/documentation/xcode/supporting-associated-domains>
- <https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns>
- <https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns>
- <https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile/>
