# Testing and diagnostics

Test the contract at the cheapest layer that can prove it, then smoke-test the native lifecycle that unit tests cannot reproduce.

## Rails

- Test `hotwire_native_app?` behavior using realistic iOS and Android user agents.
- Test browser and native branches of historical-location helpers.
- Test path-configuration endpoints, caching, content type, and backward compatibility.
- Test usable HTML when no bridge component is advertised.
- Test authentication expiry, logout, account switching, CSRF, and redirects without disabling protections globally.
- For a web-owned shell interaction, prove the CSRF-protected endpoint and HTML fallback in Rails, the browser
  API behavior in a JavaScript system test, and the resulting flow in the target WebView. Run path/Bridge
  validators only when those contracts changed.
- Fetch controller-rendered configuration URLs without a session and assert public cache headers, not only JSON shape.
- Exercise protected routes with both native and ordinary-browser user agents so a native 401 branch cannot break the browser fallback.

## iOS and Android

- Build at the locked dependency and deployment target.
- Unit-test payload decoding, route decisions, and custom destination registration.
- Test Bridge Component connect, reply, enable/disable, disconnect, and view recreation.
- Test modal-to-modal, modal-to-default, tab reselection, cold deep link, and warm deep link.
- Keep every app and test target on the intended deployment floor; a missing test-target setting can silently
  inherit a newer default and make local and CI results diverge.
- On GitHub-hosted macOS runners, run `xcrun simctl list` before `xcodebuild` so CoreSimulator recaches the
  preinstalled runtimes and devices. If Xcode still reports only generic placeholder destinations, capture the
  image version and available runtimes/devices and retry a fresh runner before downloading another platform.
- Keep debug WebView inspection and verbose logs out of release builds.

## Diagnostics

Hotwire Native Dev Tools can inspect bridge traffic, console logs, native stack, path properties, and cookies inside the app. Treat cookie inspection as sensitive and development-only. Prefer structured log/export tooling over screenshots when an AI agent needs to analyze repeated runs.

### Optional Xcode agent access

Use repository scripts and command-line checks for routine Hotwire Native work. When substantial native UI or
an unresolved native-only failure requires previews, device interaction, accessibility inspection, or LLDB
debugging, check whether the agent is running on macOS with full Xcode installed:

```sh
xcrun --find mcpbridge
```

If Apple's `mcpbridge` is available, the host agent supports MCP, and the user can open the project in Xcode and
approve external-agent access, offer the Xcode MCP as an optional higher-fidelity debugging surface. Use it for
native screens, difficult Bridge lifecycle failures, and simulator- or device-only behavior. Keep the repository's
normal build and test commands authoritative; do not make `mcpbridge` a generated-app dependency, a `bin/ios`
requirement, or a CI prerequisite.

Follow Apple's current setup guidance rather than hard-coding one agent host's configuration:
[Giving external agents access to Xcode](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode).

Capture for failures:

- requested and final URL;
- selected path properties and configuration source;
- tab/navigator and presentation context;
- bridge component, direction, event, and redacted payload;
- HTTP status or `HotwireNativeError`/Android visit error;
- native SDK and web bridge versions.

## Definition of done

A change is done only when:

- the target versions are recorded;
- all affected platform contracts agree;
- deterministic validators pass;
- Rails and available native builds/tests pass;
- fallback behavior required by an evidenced deployed-client contract is preserved;
- device-only, signing, entitlement, privacy, and store-review checks are explicitly handed off or listed when
  not run. Use `deploy-hotwire-native-ios` for the Apple deployment checks when it is installed; otherwise report
  the missing sibling Skill instead of improvising account or release operations.
