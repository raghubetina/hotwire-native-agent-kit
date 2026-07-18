# Shells and navigation

Derive shell code from the demos at the exact selected tags. Keep application policy small and explicit.

## Choose the repository layout explicitly

Place `ios/` and `android/` inside the Rails repository when the shells share one product backlog, compatible access controls, and coordinated changes with Rails. Use sibling repositories when platform teams, permissions, release automation, or compliance boundaries are genuinely separate. Do not let the agent's current working directory decide this architecture.

Before scaffolding, discover or request the native project location, product/display names, bundle/application IDs, minimum OS versions, signing team, URL schemes, and associated-domain/deep-link entitlements. These are product identifiers, not implementation defaults.

Keep one ordinary source-owned native project as the canonical application. A reviewable generator such as
XcodeGen may define project metadata while the generated project remains committed for a zero-setup open, but do
not maintain a parallel Swift Playground or generic preview wrapper that can drift from the shipping client.

## Scaffold the first web-only slice

Use the platform's normal project generator, then adapt the exact tagged upstream demo. Do not hand-author opaque Xcode project or Gradle wrapper internals when the installed IDE can generate them.

Start with the smallest shell that preserves access to the Rails product:

1. Pin the selected Hotwire Native version exactly in the resolved native dependency.
2. Add one bundled catch-all path configuration; add a versioned remote URL only after its cache/auth contract is verified.
3. Register only web destinations used by those rules. Do not copy demo-only native destinations or Bridge Components.
4. Create one navigator per chosen tab root and decide lazy loading explicitly. If there is no product case for tabs, start with one navigator.
5. Implement unauthorized-response, external HTTP(S), and system-scheme policy before the first smoke test.
6. Build, launch, navigate every tab/root, submit a fallback form, exercise a modal, and cold-restart before adding native UI.

Treat the tagged demo as API evidence, not as an application template: omit its sample routes, custom destinations, components, domains, and identifiers.

## iOS 1.3 baseline

- Configure Hotwire and register Bridge Components before creating navigators.
- Load path configuration from a bundled file first and a server URL second.
- Create the window in a scene delegate/controller and make a configured `Navigator` or `HotwireTabBarController` the root.
- With tabs, call `load(...)` and decide `lazyLoadTabs` explicitly.
- Implement `NavigatorDelegate.handle(proposal:from:)` for custom destinations.
- Handle `visitableDidFailRequest(_:error:retryHandler:)` with `HotwireNativeError`; reconcile 401 responses with the app's authentication flow.
- Keep external HTTP(S) and system schemes in route-decision handlers rather than path-rule accidents.

Useful tagged examples:

- `Demo/AppDelegate.swift`
- `Demo/SceneController.swift`
- `Demo/Tabs.swift`

For a tab shell, the minimum application-owned surface is normally an app delegate/configuration point, a scene delegate/controller, a `HotwireTab` list, a bundled path configuration, and ordinary Xcode project metadata. A one-stack shell can replace the tab controller/list with a single configured `Navigator`.

## Keep one validated application root

Derive every tab root, sign-in URL, and remote path-configuration URL from one baked application root. Production
and other distributable configurations use an explicit HTTPS host root rather than a source-code default that can
drift from artifact metadata.

A development build may accept a per-launch environment variable or launch argument so one Simulator artifact can
open different Rails previews without rebuilding native code. Keep that override behind a compile-time Debug guard,
do not persist it, and make Release ignore it even when the process environment or arguments contain the key.

Validate before constructing any derived URL:

- trim whitespace and require an absolute host root;
- accept HTTPS, plus HTTP only for loopback development hosts;
- reject credentials, non-root paths, queries, and fragments;
- normalize an optional trailing slash;
- define and test precedence when both environment and argument values exist;
- fall back visibly to the baked root when a Debug override is invalid.

The root is an origin, not a place to carry tokens or other secrets. Changing it for one launch does not prove
Universal Links, Shared Web Credentials, push, signing, or any other origin- or identity-bound capability.

## Android 1.3 baseline

- Configure `Hotwire.defaultFragmentDestination` in `Application.onCreate()`.
- Register all web, bottom-sheet, and native fragment destinations.
- Register Bridge Components and set `KotlinXJsonConverter` before navigation begins.
- Enable WebView debugging only for debug builds.
- Configure `Hotwire.config.logger.logLevel`; do not copy removed Android `debugLoggingEnabled` snippets.
- Load a bundled asset plus cached/remote path configuration.
- Use `HotwireActivity` and return navigator configurations for every tab.
- Decide `lazyLoadTabs` explicitly on `HotwireBottomNavigationController`.

Useful tagged examples:

- `demo/.../DemoApplication.kt`
- `demo/.../main/MainActivity.kt`
- `demo/.../features/web/WebFragment.kt`
- `demo/.../features/web/WebBottomSheetFragment.kt`

For a tab shell, the minimum application-owned surface is normally an `Application`, a `HotwireActivity`, a tab-definition file, registered web fragment classes, activity/navigation XML, a bundled path configuration, and ordinary Gradle/Android project metadata. Register a bottom-sheet destination only when a bundled or remote rule names its URI.

## Navigation invariants

- Each tab owns an independent navigation stack.
- Modal context is temporary and must return to the correct underlying stack.
- Server path rules control policy, but registered native destinations define what the binary can actually display.
- A remote configuration must remain compatible with every deployed app version that can fetch it.
- Cold launch, warm deep link, already-selected tab, background resume, and unauthorized responses are different paths; test them separately.

Do not scaffold signing credentials, production domains, bundle IDs, or deep-link entitlements from guesses. Discover or request those project facts. Hand Apple signing, provisioning, environment-lane, TestFlight, and App Store work to the deployment workflow after the application contract is ready.
