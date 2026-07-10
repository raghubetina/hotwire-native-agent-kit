# Bridge Components

A component is one public contract implemented three times:

1. a Stimulus controller extending `BridgeComponent`;
2. a Swift `BridgeComponent` registered on iOS;
3. a Kotlin `BridgeComponent` registered on Android.

Keep component name, event names, payload keys, reply behavior, and lifecycle semantics aligned.

## Design the contract first

Record for each event:

- sender and receiver;
- payload names, types, optionality, and size bounds;
- whether a reply is expected and which event it answers;
- what happens without native support;
- cleanup on controller disconnect, navigation, native view destruction, and process recreation.

Avoid transporting large binary/base64 payloads across the bridge. Prefer native files, uploads, identifiers, or bounded metadata.

## Web rules

- Keep HTML functional before the bridge connects.
- Call `super.connect()` and `super.disconnect()`.
- Send `disconnect` when native UI must be removed.
- Use `BridgeElement` for accessible titles and `data-bridge-*` attributes.
- Never insert scanner, NFC, URL, or native reply data with `innerHTML`; use `textContent` or safe DOM construction.
- Disable/enable matching web and native submit controls together.

## iOS rules

- Override `nonisolated class var name` when strict concurrency requires it.
- Decode with `message.data()` into explicit `Decodable` payloads.
- Access the host with `delegate?.destination as? UIViewController` when the component needs navigation UI.
- Keep references to UI the component owns and remove only those exact objects.
- Reply to the received event rather than inventing a parallel callback channel.

## Android rules

- Use `delegate.destination.fragment` as the generic `Fragment`; web bottom sheets are not `HotwireFragment` subclasses.
- Use generated/resource IDs rather than shared magic integers.
- Implement `BridgeComponentFragmentLifecycle` for view-owned UI and clear references in `onDestroyView()`.
- Decode with the configured Kotlin serialization converter and `@Serializable` payloads.
- Avoid logging full bridge messages when payloads may contain sensitive values.

Start with `assets/templates/bridge-form/`, then run `scripts/validate_bridge_contract.rb`. Its payload comparison is a text heuristic; inspect aliases and event-specific payload types manually.

## Choose dependencies deliberately

Use the Form, Menu, and Overflow Menu implementations in the tagged official iOS/Android demos as the canonical API examples. Joe Masilotti's public Bridge Components library is useful MIT-licensed pattern material, but v0.13.2's Swift package constraint excludes Hotwire Native iOS 1.3 and its public code has no automated test suite. Vendor or fork only the free components an app needs, fix lifecycle/platform issues, and test them at the target versions rather than making the whole package a default dependency.

Treat PRO native source as an optional, app-level accelerator for hardware-heavy features. Confirm current SDK compatibility and licensing before purchase or use. Never embed PRO source or derived patches in a public/shared Skill.
