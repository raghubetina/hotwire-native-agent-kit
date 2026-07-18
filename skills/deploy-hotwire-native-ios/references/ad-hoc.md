# Ad Hoc distribution

Use Ad Hoc when the owner needs a Production-signed build on a small, known set of registered devices without
TestFlight. It is useful for a specific operational constraint, not the default preview or beta-distribution path.

## Approve the account mutations first

An Ad Hoc profile contains registered device identifiers. Before changing Apple account state:

1. confirm the legal Apple-team owner, exact bundle ID, approved source SHA, target configuration, and intended
   recipients;
2. inventory whether each device is already registered and whether a current Ad Hoc profile already authorizes the
   App ID, capabilities, distribution certificate, and devices;
3. state which device registrations or profile changes are required and obtain the owner's approval for those exact
   mutations; and
4. treat UDIDs as sensitive operational data. Do not paste them into chat, logs, issues, or the repository.

Device and profile limits reset on Apple's schedule and are date-sensitive. Check the current account state and
Apple documentation instead of promising a fixed capacity from memory.

## Archive and export the approved revision

Build on the trusted macOS lane with reusable owner-controlled distribution signing material. Ask the installed
Xcode tools for current export syntax. The export must deliberately select Ad Hoc distribution; a Development or
App Store Connect export is a different channel.

Keep the export options reproducible and outside secret material. Record the source SHA, dirty state, Xcode version,
configuration, build number, bundle ID, team, profile UUID/expiration, certificate fingerprint, Rails origin, and
artifact SHA-256. Do not sign an artifact produced by an untrusted pull-request job; rebuild the approved SHA in the
trusted lane.

Inspect the exported IPA before distribution:

```sh
ruby <skill-dir>/scripts/inspect_artifact.rb path/to/App.ipa \
  --source-root . \
  --expect-clean-source \
  --expect-source-sha "$APPROVED_SHA" \
  --expect-channel ad-hoc \
  --expect-bundle-id com.example.app \
  --expect-team-id ABCDE12345 \
  --expect-aps-environment production \
  --json
```

The inspector must confirm that every app and extension carries a decodable, unexpired profile; the profile
authorizes the signed entitlements and leaf certificate; and the profile has the registered-device shape expected
for Ad Hoc distribution.

## Distribute only to the approved recipients

Obtain explicit approval before sharing the IPA. Use an owner-controlled installation mechanism appropriate to the
organization, such as Apple Configurator, managed device distribution, or an authenticated HTTPS installation
surface. Verify the current tool and OS requirements before writing instructions; do not publish the IPA at a
guessable public URL.

On a registered physical device, prove installation, launch, the baked Rails origin, authentication, Production
push, Associated Domains, and the capability that justified using Ad Hoc. Record physical observation. A successful
export or install does not prove runtime behavior.

Primary references:

- <https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile/>
- <https://developer.apple.com/help/account/devices/devices-overview/>
- <https://developer.apple.com/help/account/reference/device-registration-updates/>
