# Hotwire Native Agent Kit

An unofficial, agent-oriented toolkit for developing Hotwire Native iOS and Android clients on top of existing Rails applications.

The initial release contains one portable Agent Skill, `develop-hotwire-native`. It audits project dependencies, routes implementation work to focused references, supplies conservative path-configuration and Bridge Component templates, and validates common cross-platform contract failures.

The core Skill is agent-agnostic and follows the open Agent Skills layout. Files under `.codex-plugin/` and `skills/develop-hotwire-native/agents/` are optional host-specific presentation metadata; they do not change the workflow used by other agents.

## Install

The `gh skill` commands are currently a GitHub CLI preview and require GitHub CLI 2.90 or newer.

Install the latest GitHub release with `gh skill` (Codex example):

```sh
gh skill install raghubetina/hotwire-native-agent-kit \
  develop-hotwire-native \
  --agent codex \
  --scope user
```

For a repository-local installation shared by supported agents, run this from that repository and use project scope:

```sh
gh skill install raghubetina/hotwire-native-agent-kit \
  develop-hotwire-native \
  --agent codex \
  --scope project
```

Pin a reviewed release for reproducible use:

```sh
gh skill install raghubetina/hotwire-native-agent-kit \
  develop-hotwire-native@v0.2.2 \
  --agent codex \
  --scope user
```

Preview available updates without changing installed files:

```sh
gh skill update --dry-run
```

Update an unpinned installation:

```sh
gh skill update develop-hotwire-native
```

Pinned installations are intentionally skipped by `gh skill update`; review a newer release and reinstall with its explicit tag to move the pin.

The same Skill can be installed for another supported agent by changing `--agent`.

Version `0.2.2` is published as a portable Agent Skill. The included Codex plugin manifest is prepared for future native marketplace distribution but is not yet a marketplace listing; use `gh skill` for installation today.

## Verified baseline

The `v0.2.2` guidance and fixtures were verified on July 13, 2026 against:

- Hotwire Native iOS 1.3.0
- Hotwire Native Android 1.3.0
- Hotwire Native Bridge 1.2.2
- Action Push Native 0.3.1

The Skill audits the target application's resolved dependencies before recommending version-sensitive changes. Its compatibility matrix is a tested baseline, not permission to upgrade an application automatically.

## Repository structure

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

The repository is the canonical release source. Native marketplace manifests can be added as thin wrappers later without forking the Skill contents.

## Provenance and scope

This repository contains independently written guidance and validators plus clearly attributed template adaptations from pinned, permissively licensed upstream examples. It does not redistribute Joe Masilotti's purchased book or newsletter text, Bridge Components PRO source, or substantial code from source-available projects with incompatible terms. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the bridge template's accompanying [license notices](skills/develop-hotwire-native/assets/templates/bridge-form/LICENSES.md).

Hotwire and Hotwire Native are projects maintained by 37signals. This community project is not affiliated with or endorsed by 37signals, Hotwired, Joe Masilotti, or OpenAI.

## License

MIT. See [LICENSE](LICENSE).
