# Repository guidance

Maintain this repository as a public, agent-agnostic source for the `develop-hotwire-native` Skill.

## Boundaries

- Keep the core Skill portable. Mention a specific agent only in that agent's wrapper or UI metadata.
- Do not add purchased book or newsletter prose, Bridge Components PRO source, or substantial source-available code with incompatible terms.
- Prefer tagged upstream source, tests, and demos. Record verified refs and dates in `upstream-lock.yml`.
- Preserve upstream notices beside every adapted copy-out template; do not rely only on the repository-level license.
- Do not silently change the verified compatibility matrix. Update guidance, fixtures, tests, and release notes together.

## Structure

- Treat `skills/develop-hotwire-native/` as the canonical Skill tree.
- Keep detailed guidance in its focused `references/` files and the main `SKILL.md` as a concise router.
- Keep deterministic checks in `scripts/` and output templates in `assets/`.
- Keep `.codex-plugin/plugin.json` limited to Codex packaging metadata. Add other host wrappers without forking the core Skill.

## Verification

Run these checks before committing:

```sh
ruby skills/develop-hotwire-native/scripts/test.rb
ruby skills/develop-hotwire-native/scripts/test_validate_path_config.rb
ruby script/verify
gh skill publish --dry-run
```

When Codex's `skill-creator` and `plugin-creator` system Skills are available, also run their `quick_validate.py` and `validate_plugin.py` scripts against the Skill and repository respectively.

Also run the target Rails, Xcode, and Gradle checks when changing version-sensitive templates or guidance. If a platform cannot be exercised, document the missing check in the release notes.

## Releases

- Use semantic versions beginning at `0.1.0`.
- Keep the Git tag, `.codex-plugin/plugin.json`, `CHANGELOG.md`, and any future host manifests on the same version.
- Treat a newly verified Hotwire Native release as at least a minor release of this kit.
- Inspect every upstream change before incorporating it; do not automatically rewrite guidance from release feeds.
