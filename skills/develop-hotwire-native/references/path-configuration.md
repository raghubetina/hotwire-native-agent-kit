# Path configuration

Path rules cascade in file order. Every matching rule contributes properties; a later matching rule overrides an earlier value with the same key. Put broad defaults first and specific behavior later.

## Loading policy

- Bundle a minimal safe configuration in each app.
- Load a versioned platform-specific server configuration after the bundle.
- Keep remote configuration public, cacheable, and backward compatible.
- Change the remote schema version or endpoint when a new binary requires incompatible destinations.
- Validate both platform files in CI.

## Core shared properties

- `context`: `default` or `modal`
- `presentation`: `default`, `pop`, `replace`, `clear_all`, `replace_root`, `refresh`, or `none`; Android also accepts explicit `push`
- `query_string_presentation`: `default` or `replace`
- `pull_to_refresh_enabled`: boolean
- `animated`: boolean

## Platform properties

iOS commonly uses `view_controller`, `modal_style`, and `modal_dismiss_gesture_enabled`. Android commonly uses `uri`, `fallback_uri`, and `title`. Both platforms preserve unknown properties, so application-specific keys are allowed; document their consumer.

Do not use `presentation: "modal"`; modal is a context. On Android, register every URI destination before publishing a rule that uses it. A catch-all web URI is a useful explicit baseline even when `defaultFragmentDestination` is configured.

## Pattern guidance

- Match URL paths, not full production hosts.
- Anchor route endings such as `/new$` and `/edit$`.
- Put an explicit broad baseline such as `.*` first when using one.
- Remember that query strings participate in matching by default in current iOS and Android implementations.
- Treat the validator's Ruby regex compilation as a conservative syntax check; confirm platform-specific expressions in native tests.

Use the templates in `assets/templates/path-configuration/` and run `scripts/validate_path_config.rb` before committing.
