---
name: develop-hotwire-native
description: Audit, build, upgrade, and debug Hotwire Native iOS and Android clients for existing Rails applications. Use for assessing Rails readiness, discovering locked Rails/Turbo/Hotwire versions, scaffolding or modifying Hotwire Native 1.x shells, implementing navigation or path configuration, creating or reviewing three-sided Bridge Components, migrating 1.2-era code to 1.3, or diagnosing cross-platform contract and lifecycle failures.
---

# Develop Hotwire Native

Treat Rails as the product and the native projects as progressively enhanced clients. Inspect the target before choosing APIs or changing dependencies.

## Follow the workflow

1. Run `ruby <skill-dir>/scripts/audit_project.rb --root <project-root>`.
2. Read [compatibility-and-discovery.md](references/compatibility-and-discovery.md). Record the target's locked versions and packaging choices.
3. Classify the requested feature:
   - Keep it on the web when responsive HTML provides sufficient fidelity.
   - Use a Bridge Component for one native control or device capability driven by usable web markup.
   - Use a native screen for a whole interaction requiring native performance, gestures, or SDKs.
4. Load only the task-specific references in the routing table below.
5. Implement the smallest complete slice across Rails, iOS, and Android. Preserve older deployed-client fallbacks.
6. Run the relevant validators and the target project's actual Rails, Xcode, and Gradle checks.
7. Report verified versions, tests run, device-only checks remaining, and any upstream APIs newer than this Skill's matrix.

## Enforce these gates

- Do not make version-sensitive edits before inspecting lockfiles and native dependency files.
- Do not upgrade Rails, Turbo, Hotwire Native, deployment targets, or build tooling unless the request includes that upgrade.
- Prefer tagged upstream source, tests, and demos over remembered snippets or lagging prose documentation.
- Keep Bridge Components as a three-sided contract: web controller, Swift component, and Kotlin component in the same change.
- Keep the HTML fallback usable when no native component is registered.
- Remove only UI owned by the component on disconnect and native view destruction.
- On Android, depend on the generic destination `Fragment`; do not cast every destination to `HotwireFragment`. Implement 1.3 view-lifecycle cleanup for view-owned UI.
- Bundle a baseline path configuration and layer a cached/remote configuration over it. Treat later matching rules as property overrides.
- Do not redistribute purchased book/newsletter text or commercial Bridge Components PRO source. Summarize independently and use permissively licensed examples.

## Route the task

| Task | Read |
|---|---|
| Dependency discovery, upgrades, source conflicts | [compatibility-and-discovery.md](references/compatibility-and-discovery.md) |
| Existing Rails app readiness and server integration | [rails-readiness.md](references/rails-readiness.md) |
| iOS/Android shell, tabs, routing, errors, logging | [shells-and-navigation.md](references/shells-and-navigation.md) |
| Path rules, bundled/remote loading, cross-platform drift | [path-configuration.md](references/path-configuration.md) |
| Bridge design, lifecycle, registration, payloads | [bridge-components.md](references/bridge-components.md) |
| Tests, diagnostics, security, definition of done | [testing-and-diagnostics.md](references/testing-and-diagnostics.md) |

## Use deterministic checks

```bash
# Inspect a target project without changing it.
ruby <skill-dir>/scripts/audit_project.rb --root .

# Validate one path configuration or compare the platforms.
ruby <skill-dir>/scripts/validate_path_config.rb --platform ios config/ios.json
ruby <skill-dir>/scripts/validate_path_config.rb --platform android config/android.json
ruby <skill-dir>/scripts/validate_path_config.rb --compare config/android.json config/ios.json
ruby <skill-dir>/scripts/validate_path_config.rb --platform ios https://example.com/configurations/ios_v1.json

# Check component names, sent events, cleanup, and likely payload drift.
ruby <skill-dir>/scripts/validate_bridge_contract.rb \
  --web app/javascript/controllers/bridge \
  --ios ios/App/Bridge \
  --android android/app/src/main
```

Treat validator payload findings as heuristics and inspect the source before editing. Treat malformed JSON, invalid patterns, invalid core property values, and missing platform component counterparts as blocking errors.

## Start from maintained templates

Use `assets/templates/path-configuration/` for cascading baseline configurations and `assets/templates/bridge-form/` for a lifecycle-safe starting component. Adapt package names, toolbar lookup, presentation, styling, and app-specific error behavior; do not copy templates blindly.

## Finish with evidence

Require, in proportion to the change:

- Rails request/system tests for native variants, redirects, and configuration endpoints;
- iOS build/tests at the locked package version;
- Android assemble/tests at the locked Maven version;
- validator output for changed path or bridge contracts;
- simulator/device smoke checks for navigation, disconnect cleanup, authentication, external links, and process restarts.

If a platform cannot be built, say exactly which check was not run and why.
