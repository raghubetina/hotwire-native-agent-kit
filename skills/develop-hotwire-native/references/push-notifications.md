# Push notifications

Hotwire Native provides no APNs or FCM implementation. Treat push as an application capability spanning Rails,
the native shell, provider credentials, and physical-device lifecycle.

## Prove the registration stages separately

1. Connect an explicit Bridge Component only after the page has the required authenticated account context.
2. Ask for notification permission at a product-selected moment. A prior decision may suppress the system dialog.
3. Register with the OS and receive a token or delegate error. Convert token bytes deterministically and never log
   the token.
4. Retain the token in memory until the exact WebView that emitted the authenticated Bridge signal can provide its
   CSRF token and matching cookies.
5. POST to an authenticated Rails endpoint and bind the device to the current account. A stored row proves
   registration, not provider acceptance or receipt.
6. Deliver asynchronously, observe the provider result without secrets, and verify receipt on a physical device.
7. Test foreground, background, terminated launch, and warm/cold notification taps independently.

Bridge connection must happen on the first eligible authenticated render. A tab switch can diagnose a missing
connection but must not be required to trigger registration.

## Make the APNs environment part of the device contract

Xcode development installs receive Sandbox tokens. TestFlight and App Store installs receive Production tokens.
One Rails deployment can own both, so never choose the endpoint with one deployment-wide flag.

Have iOS inspect `aps-environment` in its embedded provisioning profile and register normalized `sandbox` or
`production` beside the token. TestFlight/App Store packaging may omit the profile; use the store receipt as the
Production signal and keep build-configuration inference only as a logged last-resort fallback. On Rails:

- require and validate the environment for every Apple registration;
- persist it beside the token and constrain allowed platform/environment combinations in the database;
- treat an environment change like an identity/binding change so queued jobs cannot silently use stale metadata;
- select both the APNs endpoint and the environment-scoped credential per device;
- label the environment without exposing the token in account diagnostics.

Do not carry a missing-environment fallback merely because an earlier prototype binary existed. Inventory actual
deployed users and versions first. For a golden reference or experiment with no users, rebuild the binary, reject
incomplete registrations, and extract only the final contract.

Apple's newer topic-specific keys are environment-scoped. Keep separate Sandbox and Production key IDs/private
keys for each app topic; never place a team-scoped organization key in an individual generated app. The App Store
Connect API key used to upload builds is a different credential from the APNs provider key used by Rails.

## Keep delivery account-scoped and observable

User-targeted push depends on an account layer. Put a fixed self-test on the authenticated account/profile page:

- scope device lookup through the current account;
- accept no arbitrary recipient, token, title, body, path, or URL;
- keep ordinary session, CSRF, and business rate limits;
- enqueue asynchronously and say **queued**, never **delivered**;
- correlate queued, provider-accepted, provider-error, and invalidated states without logging secrets or PII.

Unbind the current installation on sign-out before another account can inherit it. Anonymous broadcast or topic
notifications are a separate capability, not an implicit account-push variant.

For record-created events, enqueue after commit so every writer follows the rule and rolled-back records produce no
notification. Mark canonical sample/seed records as explicit non-events. Inspect the locked delivery gem's job
inheritance, retry, deserialization, and invalid-token behavior rather than assuming application job policy applies.

At Action Push Native 0.3.1, provider configuration is global and `Device#push` owns token-error cleanup. If a
target needs per-device APNs routing, preserve that cleanup while introducing the smallest app-owned provider
selection seam; do not build a parallel APNs client.

Primary references:

- <https://developer.apple.com/documentation/bundleresources/entitlements/aps-environment>
- <https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns>
- <https://github.com/rails/action_push_native/tree/v0.3.1>
