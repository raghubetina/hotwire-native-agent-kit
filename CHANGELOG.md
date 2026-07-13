# Changelog

## 0.2.2 - 2026-07-13

- Narrow managed-preview guidance to the generated app's artifact, capability, ownership, and expiration
  contract.
- Move service-provider concerns such as GitHub App authorization, artifact ingestion, signing-key custody,
  provisioning, uploads, and tester administration out of the app-maintainer Skill.
- Retain app-owner signing, final IPA verification, TestFlight, and App Store distribution guidance.

## 0.2.1 - 2026-07-12

- Keep standards-based WebView behavior on the web unless a native capability actually requires a Bridge or
  destination, and require native shells to preserve discoverability when browser chrome is absent.
- Add GitHub-hosted simulator bootstrap diagnostics for missing placeholder destinations.
- Separate untrusted compilation from trusted signing and document why a reusable workflow alone does not
  isolate organization credentials from caller-controlled source.
- Record the disposable-runner certificate lifecycle discovered by repeated clean-runner signing experiments.

## 0.2.0 - 2026-07-11

- Add end-to-end push-notification guidance, including authenticated registration, per-device APNs environment
  routing, environment-scoped keys, account self-tests, and lifecycle verification.
- Add signing and distribution guidance for local Macs, hosted builders, TestFlight, project ownership, and
  archive entitlement verification.
- Require evidence before preserving legacy-client fallbacks; no-user prototypes should remove transitional
  branches before becoming golden references.
- Add durable native-session, Shared Web Credentials, and native-target deployment-floor checks.
- Verify Action Push Native 0.3.1 as the current provider baseline.

## 0.1.1 - 2026-07-10

- Exclude installed agent-host directories from project audits so bundled Skill fixtures cannot be mistaken for application code.

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
