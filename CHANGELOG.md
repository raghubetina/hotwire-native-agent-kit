# Changelog

## 0.0.3 - 2026-07-14

- Document safe upgrades for pinned and unpinned installations.
- Use the explicit `--pin` flag so project-scoped installs are reported and treated as pinned by GitHub CLI 2.95
  and 2.96.
- Document clean replacement for pinned upgrades so removed or renamed Skill files cannot linger.
- Keep `develop-hotwire-native` and `deploy-hotwire-native-ios` on one reviewed release and verify their bundled
  tests after upgrading.
- Leave both Skill trees unchanged from `v0.0.2`; this release improves repository-level installation, upgrade,
  and release verification guidance.

## 0.0.2 - 2026-07-14

- Add the public `deploy-hotwire-native-ios` Skill for owner-controlled environment lanes, direct-device builds,
  Ad Hoc distribution, signing, provisioning, deterministic deployment/artifact inspection, CI, TestFlight, and
  App Store handoff.
- Narrow `develop-hotwire-native` to product-facing Rails/iOS/Android implementation and runtime behavior.
- Keep managed-signing provider control-plane operations outside both public Skills.
- Add explicit owner-approval, credential-lifecycle, release-provenance, and untrusted-build boundaries.
- Fail closed when signed artifacts lack an authorized profile/certificate, carry an unexpected provisioning channel,
  omit source provenance, or request an entitlement the inspector does not model yet.
- Replace private and transient experiment links with a public support-status contract that labels advisory paths.
- Pin the kit's own CI actions and strengthen release-structure verification.

## 0.0.1 - 2026-07-14

- Add the `develop-hotwire-native` Skill for auditing, building, upgrading, and debugging Rails-powered iOS and Android clients.
- Establish a verified Hotwire Native 1.3 compatibility baseline and version-discovery workflow.
- Add project, path-configuration, and three-sided Bridge Component validators plus lifecycle-safe templates.
- Cover navigation, native-session persistence, Shared Web Credentials, push registration and delivery, signing, TestFlight, and App Store handoff.
- Separate application-owned deployment contracts from managed-preview service operations and credential custody.
- Require evidence before preserving compatibility branches; no-user prototypes should use the final contract directly.
- Treat Apple's Xcode MCP as an optional native-heavy debugging surface while keeping repository scripts authoritative.
- Exclude installed agent-host directories from project audits so bundled Skill fixtures are never mistaken for application code.

Validation notes:

- The Skill and plugin schemas, Ruby scripts, bundled JSON, JavaScript syntax, Swift syntax, and cross-platform bridge contracts were checked.
- The Kotlin template was structurally validated but not compiled inside a complete Android host project.
- No complete Xcode or Gradle application build was run for the generic templates; consumers must adapt and compile them in their target application.
