# Changelog

## 0.1.0 - 2026-07-10

- Add the `develop-hotwire-native` Skill.
- Add project, path-configuration, and Bridge Component validators.
- Validate local, streamed, and live HTTP(S) path configurations without rereading one-shot inputs.
- Add lifecycle-safe iOS, Android, and web templates.
- Establish the verified Hotwire Native 1.3 compatibility baseline.

Validation notes:

- The Skill and plugin schemas, Ruby scripts, bundled JSON, JavaScript syntax, Swift syntax, and cross-platform bridge contracts were checked.
- The Kotlin template was structurally validated but not compiled inside a complete Android host project.
- No complete Xcode or Gradle application build was run for the generic templates; consumers must adapt and compile them in their target application.
