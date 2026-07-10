# Testing and diagnostics

Test the contract at the cheapest layer that can prove it, then smoke-test the native lifecycle that unit tests cannot reproduce.

## Rails

- Test `hotwire_native_app?` behavior using realistic iOS and Android user agents.
- Test browser and native branches of historical-location helpers.
- Test path-configuration endpoints, caching, content type, and backward compatibility.
- Test usable HTML when no bridge component is advertised.
- Test authentication expiry, logout, account switching, CSRF, and redirects without disabling protections globally.
- Fetch controller-rendered configuration URLs without a session and assert public cache headers, not only JSON shape.
- Exercise protected routes with both native and ordinary-browser user agents so a native 401 branch cannot break the browser fallback.

## iOS and Android

- Build at the locked dependency and deployment target.
- Unit-test payload decoding, route decisions, and custom destination registration.
- Test Bridge Component connect, reply, enable/disable, disconnect, and view recreation.
- Test modal-to-modal, modal-to-default, tab reselection, cold deep link, and warm deep link.
- Keep debug WebView inspection and verbose logs out of release builds.

## Diagnostics

Hotwire Native Dev Tools can inspect bridge traffic, console logs, native stack, path properties, and cookies inside the app. Treat cookie inspection as sensitive and development-only. Prefer structured log/export tooling over screenshots when an AI agent needs to analyze repeated runs.

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
- fallback behavior is preserved;
- device-only, signing, entitlement, privacy, and store-review checks are explicitly listed when not run.
