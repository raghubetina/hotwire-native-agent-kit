# Rails readiness

Audit the existing application before adding native projects. A native shell amplifies web assumptions; it does not repair them.

## Required baseline

- Serve production over HTTPS.
- Keep ordinary links, forms, redirects, validation errors, and authentication functional in a mobile browser.
- Confirm Turbo-compatible response behavior and identify intentional full-page/external navigations.
- Confirm cookies, CSRF protection, session expiry, logout, account switching, and unauthorized responses.
- Identify CSP restrictions, third-party widgets, downloads, uploads, camera/file inputs, OAuth, and external domains.
- Make layouts responsive without relying on native user-agent detection for basic usability.

`turbo-rails` exposes `hotwire_native_app?` and the legacy alias `turbo_native_app?`. Use native detection to enhance presentation, not to remove the web fallback.

## Capability-aware enhancement

Hotwire Native appends registered bridge-component names to its user agent. Prefer a server helper that distinguishes:

1. an ordinary browser;
2. a Hotwire Native client;
3. a Hotwire Native client that advertises the specific component.

Render usable HTML in every case. Hide or replace the web control only after the matching native capability is known. Fizzy's public Rails source is a useful production pattern for capability parsing, but it is O'Saasy-licensed; summarize the approach instead of embedding substantial code.

## Path-configuration endpoint

- Serve public, cacheable, versioned, platform-specific JSON such as `/configurations/ios_v1.json` and `/configurations/android_v1.json`.
- Keep the endpoint independent of an authenticated application layout.
- Return valid configuration even when the user has no session.
- Test content type, caching, malformed-template prevention, and the fallback behavior used by old app versions.
- Never ship a remote-only configuration; bundle a safe baseline in each native app.
- Inspect controller-rendered endpoints as well as checked-in JSON files. Exercise the real URL without a session and verify the response rather than inferring readiness from route names.

If an existing remote configuration names native destination URIs or Bridge Components that the new binary will not register, do not fetch it from the first web-only shell. Publish a separate versioned shell-safe endpoint or keep the bundled baseline until compatibility is established.

## Native navigation responses

Use the current `turbo-rails` helpers rather than hand-building historical-location URLs:

- `recede_or_redirect_to` / `recede_or_redirect_back_or_to`
- `resume_or_redirect_to` / `resume_or_redirect_back_or_to`
- `refresh_or_redirect_to` / `refresh_or_redirect_back_or_to`

Exercise both branches in tests: the historical-location redirect for a native user agent and the normal redirect for browsers.

Likewise, keep authentication usable in a browser. A native 401 that the shell converts into a sign-in route needs an explicit non-native redirect or rendered sign-in fallback; a bare 401 for every client is not progressive enhancement.

## Readiness output

Before scaffolding, report:

- detected versions and packaging;
- authentication/session model;
- native-safe and unsafe routes;
- required external-domain handling;
- candidate tab roots and modal routes;
- first Bridge Component candidate;
- risks requiring product or security decisions.
