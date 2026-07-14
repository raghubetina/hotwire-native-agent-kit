# Changelog

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
