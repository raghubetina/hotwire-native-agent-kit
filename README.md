# Hotwire Native Agent Kit

An unofficial, agent-oriented toolkit for developing and deploying owned Hotwire Native applications backed by Rails.

The repository separates two jobs that are often mixed together:

| Skill | Use it for |
| --- | --- |
| `develop-hotwire-native` | Audit a Rails app; build or debug iOS/Android shells, navigation, path configuration, Bridge Components, push registration, and cross-platform lifecycle behavior |
| `deploy-hotwire-native-ios` | Choose iOS build/distribution lanes; configure environments; build local or hosted-Simulator previews; manage owner signing/provisioning; verify artifacts; and prepare TestFlight/App Store delivery |

Both Skills are for people who own the ordinary Rails and native source. They are not a standalone app generator or a managed build/signing service. A provider that offers managed TestFlight previews must keep its credential custody, artifact admission, signing policy, uploads, and tester administration in its own private control plane.

The reviewed `v0.0.4` release contains both Skills. Install them independently so each target repository receives only the guidance it needs.

## Quick start: application development

You need:

- an existing Rails repository;
- [GitHub CLI](https://cli.github.com/) 2.95 or newer (the `gh skill` commands are currently a preview);
- Ruby to run the bundled audits and validators; and
- access to Xcode on a Mac or the Android toolchain when the requested work needs that platform to compile; a hosted runner is fine.

From the Rails repository, install the reviewed release at project scope:

```sh
gh skill install raghubetina/hotwire-native-agent-kit \
  develop-hotwire-native \
  --pin v0.0.4 \
  --agent codex \
  --scope project
```

Then ask your agent to inspect before changing the app:

> Use the develop-hotwire-native skill to audit this Rails app for Hotwire Native readiness. Do not make changes yet. Report the resolved versions, what already exists, what is missing, and the smallest useful next slice.

After reviewing the audit, request one complete slice—for example, an iOS shell, durable path configuration, a three-sided Bridge Component, push registration, or a specific lifecycle fix.

## Quick start: iOS deployment

Install the deployment Skill independently in the application repository:

```sh
gh skill install raghubetina/hotwire-native-agent-kit \
  deploy-hotwire-native-ios \
  --pin v0.0.4 \
  --agent codex \
  --scope project
```

Its first useful prompt should identify the ownership and evidence boundary before changing signing:

> Use the deploy-hotwire-native-ios skill to audit this app's iOS deployment path. Do not change credentials or Apple resources. Report who owns the source and Apple team, where Xcode runs, the Development/Staging/Production configuration, available install channels, and the smallest next proof.

The deployment Skill deliberately does not assume that every user needs a paid Apple account. It distinguishes
browser, local or hosted Simulator, free Personal Team, paid-team direct device, TestFlight, and App Store paths,
discovers which commands and executors the checked-out app actually has, then asks for the least expensive path that
proves the requested claim.

When one task crosses product behavior and Apple deployment, install both Skills at the same release tag. If only one
is installed, its agent should report the missing handoff rather than absorbing the other Skill's responsibilities.

## Installation choices

The pinned, project-scoped command is recommended for a first trial because it keeps the installation inside the
target repository. Commit installed Skill files when everyone working in that repository should share the same
reviewed version. Use the explicit `--pin` flag. In GitHub CLI 2.95 and 2.96, `skill@version` checks out that
version but is still reported as unpinned and can advance during `gh skill update`.

To follow the latest published release instead of pinning a version:

```sh
gh skill install raghubetina/hotwire-native-agent-kit \
  develop-hotwire-native \
  --agent codex \
  --scope project
```

To make a released Skill available across projects, use `--scope user`:

```sh
gh skill install raghubetina/hotwire-native-agent-kit \
  develop-hotwire-native \
  --agent codex \
  --scope user
```

## Upgrading

Version `v0.0.4` changes both Skill trees: `develop-hotwire-native` gains the app-side origin contract, while
`deploy-hotwire-native-ios` gains the portable hosted-Simulator lane and artifact inspector. An existing installation
must be clean-replaced to receive those changes. Use the workflow below for this and future reviewed releases.

First inspect what is installed from the target repository:

```sh
gh skill list \
  --agent codex \
  --scope project \
  --json skillName,sourceURL,version,pinned,path
```

Keep custom application guidance outside the installed Skill directories. An upgrade replaces those directories;
start from a clean worktree and preserve any intentional local changes before continuing.

### Upgrade an unpinned installation

Preview updates without changing installed files:

```sh
gh skill update develop-hotwire-native deploy-hotwire-native-ios \
  --dir .agents/skills \
  --dry-run
```

Update an unpinned installation:

```sh
gh skill update develop-hotwire-native deploy-hotwire-native-ios \
  --dir .agents/skills
```

Name only the Skills that are installed. With GitHub CLI 2.95 and 2.96, `gh skill update` replaces the installed
Skill tree: it overwrites local edits and removes both retired upstream files and locally added files. Inspect or
move any customization first.

### Upgrade the recommended pinned installation

Pinned installations are intentionally skipped by `gh skill update`. Review the
[changelog](CHANGELOG.md), preview the target release, then clean-replace each installed Skill. When both Skills are
installed, move them to the same kit version. A clean replacement avoids keeping files that the newer release
removed. The example below upgrades both committed, project-scoped Codex Skills to `v0.0.4`; omit a Skill's preview,
remove, install, and test commands when that Skill is not installed. If the Skill directories are not tracked by
Git, preserve any intentional customization elsewhere and remove only those exact directories before installing
their replacements.

```sh
gh skill preview raghubetina/hotwire-native-agent-kit \
  develop-hotwire-native@v0.0.4

gh skill preview raghubetina/hotwire-native-agent-kit \
  deploy-hotwire-native-ios@v0.0.4

git status --short

git rm -r .agents/skills/develop-hotwire-native
git rm -r .agents/skills/deploy-hotwire-native-ios

gh skill install raghubetina/hotwire-native-agent-kit \
  develop-hotwire-native \
  --pin v0.0.4 \
  --agent codex \
  --scope project

gh skill install raghubetina/hotwire-native-agent-kit \
  deploy-hotwire-native-ios \
  --pin v0.0.4 \
  --agent codex \
  --scope project

ruby .agents/skills/develop-hotwire-native/scripts/test.rb
ruby .agents/skills/develop-hotwire-native/scripts/test_validate_path_config.rb
ruby .agents/skills/deploy-hotwire-native-ios/scripts/test.rb

git add -A .agents/skills
git diff --cached -- .agents/skills
git commit -m "Update Hotwire Native Agent Kit to v0.0.4"
```

Do not substitute `gh skill install --force` for the removal step: in GitHub CLI 2.95 and 2.96, a forced install
overwrites known Skill files but preserves extra files inside the directory. Keeping both Skills on one release
prevents product-development and deployment guidance from drifting apart.

To stop pinning and follow the latest published release instead, let `gh skill` replace the installed trees and
remove their pinned metadata:

```sh
gh skill update develop-hotwire-native deploy-hotwire-native-ios \
  --dir .agents/skills \
  --unpin
```

Run `gh skill list` again after either path to verify the installed version and `pinned` state.

The core Skills follow the open Agent Skills layout and remain agent-agnostic. Change `--agent` to another host supported by `gh skill`; run `gh skill install --help` for the current list.

Version `0.0.4` is published as portable Agent Skills. The included Codex plugin manifest is prepared for future native marketplace distribution but is not yet a marketplace listing; use `gh skill` for installation today.

## Scope and limits

### `develop-hotwire-native`

- Its static audit is orientation, not runtime verification.
- It inspects locked dependencies before version-sensitive advice and does not authorize upgrades on its own.
- Bundled path and Bridge templates must be adapted and compiled in the target app.
- Device-only push, Universal Links, AutoFill, camera, and lifecycle behavior still require appropriate physical tests.

### `deploy-hotwire-native-ios`

- The supported Apple-toolchain path runs Xcode command-line tools on macOS somewhere, but the GUI need not be the daily interface.
- Unsigned compilation, Development signing, final entitlements, TestFlight processing, and physical receipt are separate proof levels.
- A hosted-Simulator preview uses a short-lived unsigned Debug artifact from the canonical project; it is not a
  signing service or physical-device proof.
- A hosted-provider adapter may be source-owned and exposed through an explicit
  `bin/ios preview <provider>` namespace, but it remains replaceable, keeps credentials out of the repository, and
  consumes the unchanged portable artifact. Provider-specific implementation and account policy stay outside this
  provider-neutral Skill.
- Apple-account limits, runner images, roles, and review rules are date-sensitive; the Skill routes agents to current primary sources and installed tool help.
- Owner signing is in scope. A third-party provider's private signing service is not.

## Verified baseline

The `v0.0.4` development guidance and fixtures were verified on July 18, 2026 against:

- Hotwire Native iOS 1.3.0
- Hotwire Native Android 1.3.0
- Hotwire Native Bridge 1.2.2
- Action Push Native 0.3.1

The deployment Skill starts from hosted-Simulator, physical-device, TestFlight, GitHub-hosted macOS, XcodeGen, and
APNs experiments. Its support-status reference distinguishes proven paths from advisory guidance; an earlier proof
level never substitutes for an unrun Personal Team, App Store, or device-capability test.

## For contributors

The repository is the canonical release source. Host-specific manifests and presentation metadata remain thin wrappers around the portable Skills.

```text
.codex-plugin/plugin.json
skills/
  develop-hotwire-native/
    LICENSE
    SKILL.md
    agents/openai.yaml
    assets/
    references/
    scripts/
  deploy-hotwire-native-ios/
    LICENSE
    SKILL.md
    agents/openai.yaml
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
