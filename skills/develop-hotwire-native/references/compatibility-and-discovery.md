# Compatibility and discovery

Verified on 2026-07-10 against Hotwire Native iOS 1.3.0, Android 1.3.0, and Hotwire Native Bridge 1.2.2.

## Source order

Use this order when sources disagree:

1. Tagged SDK source and tests for the target version.
2. Demo code contained in that tagged SDK repository.
3. Release notes for that version.
4. Official documentation after checking its displayed version.
5. Production reference applications and permissively licensed community examples.
6. Independently synthesized handbook guidance.

The official documentation can lag releases. Never infer that a symbol exists merely because a current-looking article shows it.

## Discover before editing

Run `scripts/audit_project.rb`. Also inspect directly when present:

- `Gemfile.lock`: Rails, `turbo-rails`, authentication and push dependencies.
- `package.json`, lockfile, or `config/importmap.rb`: Stimulus, Turbo, `@hotwired/hotwire-native-bridge`.
- every `Package.resolved`/`Package.swift`: iOS package version or range.
- Gradle version catalogs and build files: `dev.hotwire:core` and `dev.hotwire:navigation-fragments`.
- native deployment targets, application identifiers, URL schemes, associated domains, and signing configuration.
- existing bridge controller directories and path-configuration endpoints/files.

Use the target's installed versions unless the task explicitly requests an upgrade. When a range crosses a minor release, inspect the resolved lock rather than trusting the manifest constraint.

## Final 1.3 changes to guard

- iOS constructs `Navigator` with a configuration. Route-decision handling uses `VisitProposal` and `Navigating`; visit failures use `HotwireNativeError`.
- iOS uses `hideTabBarWhenPushed` and configures lazy tabs on `HotwireTabBarController(..., lazyLoadTabs:)`.
- Android route handlers and custom route decisions receive `VisitProposal`.
- Android configures `Hotwire.config.logger.logLevel`; `debugLoggingEnabled` is not an Android 1.3 option.
- Android 1.3 calls `BridgeComponentFragmentLifecycle.onViewCreated()` and `onDestroyView()` around fragment-view recreation.

When supporting 1.2 and 1.3 simultaneously, isolate version differences rather than mixing snippets from both generations.

## Primary sources

- iOS 1.3.0: <https://github.com/hotwired/hotwire-native-ios/tree/1.3.0>
- Android 1.3.0: <https://github.com/hotwired/hotwire-native-android/tree/1.3.0>
- Web bridge 1.2.2: <https://github.com/hotwired/hotwire-native-bridge/tree/v1.2.2>
- Rails integration: <https://github.com/hotwired/turbo-rails>
- Official overview: <https://native.hotwired.dev/>

The separate Rails demo repository currently has no explicit license file. Cite it as official documentation; avoid copying substantial code into a distributable artifact without clarification.
