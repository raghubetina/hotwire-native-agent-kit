# Hotwire Native Agent Kit

An unofficial, agent-oriented toolkit for developing Hotwire Native iOS and Android clients for existing Rails applications.

The repository currently publishes one portable Agent Skill, `develop-hotwire-native`. It helps an AI coding agent:

- audit a Rails application and its resolved Hotwire Native dependencies before making changes;
- build or debug iOS and Android shells, navigation, tabs, and path configuration;
- implement three-sided Bridge Components across Rails, Swift, and Kotlin;
- integrate and diagnose push notifications;
- reason about signing, hosted builders, TestFlight, and App Store handoff; and
- validate common cross-platform contract and lifecycle failures.

This is for people maintaining an existing Rails application with an AI coding agent. It is not a standalone app generator or a managed build and signing service.

## Quick start

You need:

- an existing Rails repository;
- [GitHub CLI](https://cli.github.com/) 2.90 or newer (the `gh skill` commands are currently a preview);
- Ruby to run the bundled audits and validators; and
- access to Xcode on a Mac or the Android toolchain when the requested work needs that platform to compile; a hosted runner is fine.

From the Rails repository, install the reviewed `v0.0.1` release at project scope:

```sh
gh skill install raghubetina/hotwire-native-agent-kit \
  develop-hotwire-native@v0.0.1 \
  --agent codex \
  --scope project
```

Then ask your agent to inspect the application before changing it:

> Use the develop-hotwire-native skill to audit this Rails app for Hotwire Native readiness. Do not make changes yet. Report the resolved versions, what already exists, what is missing, and the smallest useful next slice.

After reviewing the audit, ask for one complete slice—for example, an iOS shell, durable path configuration, a three-sided Bridge Component, push registration, or a specific lifecycle bug fix.

The core Skill follows the open Agent Skills layout and is agent-agnostic. To install it for another agent supported by `gh skill`, change the `--agent` value; run `gh skill install --help` to see the current list.

## Installation choices

The pinned, project-scoped command above is recommended for a first trial because it keeps the installation inside the target repository. Commit the installed Skill files if everyone working in the repository should share the same version.

To follow the latest published release instead of pinning a version:

```sh
gh skill install raghubetina/hotwire-native-agent-kit \
  develop-hotwire-native \
  --agent codex \
  --scope project
```

To make the Skill available to the agent across all of your projects, use user scope:

```sh
gh skill install raghubetina/hotwire-native-agent-kit \
  develop-hotwire-native \
  --agent codex \
  --scope user
```

Preview updates without changing installed files:

```sh
gh skill update --dry-run
```

Update an unpinned installation:

```sh
gh skill update develop-hotwire-native
```

Pinned installations are intentionally skipped by `gh skill update`. Review a newer release and reinstall it with an explicit tag when you want to move the pin.

Version `0.0.1` is published as a portable Agent Skill. The included Codex plugin manifest is prepared for future native marketplace distribution but is not yet a marketplace listing; use `gh skill` for installation today.

## Scope and limits

- The project audit is static evidence, not runtime verification. The agent must still exercise relevant Rails endpoints, native builds, simulators, and physical devices.
- The Skill inspects locked dependencies before giving version-sensitive advice and does not authorize dependency or deployment-target upgrades on its own.
- Bundled path-configuration and Bridge Component templates are starting points. They must be adapted to the target app and compiled there.
- iOS signing, push delivery, universal links, camera access, and similar capabilities require final verification on appropriate devices and distribution builds.
- The application owns its source, capabilities, artifact contract, and signing handoff. The Skill does not operate a provider's GitHub App, artifact ingestion, signing-key custody, provisioning service, upload service, or tester administration.

## Verified baseline

The `v0.0.1` guidance and fixtures were verified on July 14, 2026 against:

- Hotwire Native iOS 1.3.0
- Hotwire Native Android 1.3.0
- Hotwire Native Bridge 1.2.2
- Action Push Native 0.3.1

The compatibility matrix is a tested baseline, not permission to upgrade a target application automatically. The Skill audits the application's resolved dependencies before recommending APIs or changes.

## For contributors

The repository is the canonical release source. Host-specific manifests and presentation metadata remain thin wrappers around the portable Skill.

```text
.codex-plugin/plugin.json
skills/develop-hotwire-native/
  SKILL.md
  agents/openai.yaml
  assets/
  references/
  scripts/
upstream-lock.yml
```

See [`AGENTS.md`](AGENTS.md) for repository boundaries and required verification commands.

## Provenance

This repository contains independently written guidance and validators plus clearly attributed template adaptations from pinned, permissively licensed upstream examples. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the bridge template's accompanying [license notices](skills/develop-hotwire-native/assets/templates/bridge-form/LICENSES.md).

Hotwire and Hotwire Native are maintained by 37signals, and Bridge Components is maintained by Joe Masilotti. This independent community project builds on their permissively licensed public work and preserves the notices required by each adapted source.

## License

MIT. See [LICENSE](LICENSE).
