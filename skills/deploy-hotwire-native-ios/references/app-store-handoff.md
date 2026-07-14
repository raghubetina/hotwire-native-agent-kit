# App Store readiness and handoff

Treat App Store submission as a product, legal, operational, and technical release. Automation may prepare and
validate inputs; the app owner must approve the answers, submitted build, review request, and release policy.

## Establish ownership and roles

Record the legal Apple-team owner, App Store Connect app record, bundle ID, SKU, primary locale, and people who can
approve agreements and releases. Confirm that the Account Holder has accepted current agreements and that the
upload/release operator has the required role.

A managed-preview record is not automatically transferable. Before promising transfer, check Apple's current
criteria for the app's capabilities, subscriptions, groups, and agreements. When transfer is unavailable, create a
new owner record and rebuild every team-bound contract under the owner's team.

## Prepare the product record

Inventory and obtain owner approval for:

- app name, subtitle, description, keywords, category, age rating, support URL, marketing URL, and screenshots;
- privacy policy URL and App Privacy answers based on the app and every included SDK;
- review contact, review notes, and a working demo account or documented sign-in path;
- export-compliance answers and any required documentation;
- content rights, regulated-domain declarations, and availability/price decisions;
- account-deletion behavior when the app supports account creation;
- release mode: manual, automatic after approval, or phased release.

Do not invent legal, privacy, encryption, age-rating, or content-rights answers. Present the evidence and ask the
owner to decide.

## Verify the submitted binary

Before upload and again before selecting the build for review:

1. require a committed source SHA and disclose any dirty state;
2. archive the exact approved configuration and monotonically increasing build number;
3. inspect every signed app and extension, embedded profile, identity, entitlements, version, bundle ID, Rails
   origin, and artifact SHA-256;
4. check privacy manifests and required-reason API declarations for the app and included SDKs;
5. install the processed build through TestFlight and prove authentication, account deletion, deep links,
   Production push, release-only configuration, and primary user journeys on a physical device.

Upload success is not submission. App Store Connect processing, selected-build metadata, review submission,
approval, and store installation are separate checkpoints.

## Require explicit release approvals

Obtain separate approval before:

- uploading the candidate build;
- saving owner-authored compliance or privacy answers;
- adding the version for review;
- submitting it to App Review; and
- releasing an approved version.

Report the selected build, artifact digest, source SHA, metadata locale, review account status, unresolved warnings,
submission ID/status, and release decision. Never expose review passwords or API keys in logs or chat.

Primary references:

- <https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/>
- <https://developer.apple.com/documentation/bundleresources/privacy-manifest-files>
- <https://developer.apple.com/app-store/app-privacy-details/>
- <https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/>
- <https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/>
- <https://developer.apple.com/support/offering-account-deletion-in-your-app/>
- <https://developer.apple.com/help/app-store-connect/transfer-an-app/overview-of-app-transfer/>
