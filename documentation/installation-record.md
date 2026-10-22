# Redmine Microsoft 365 SMTP plugin

## Current source: 2.0.1

Browser authorization code + S256 PKCE replaces application-only authentication.
Current distribution: `dist/redmine_microsoft365_smtp-2.0.1.zip`.
Implementation alone does not upgrade an existing live installation. See the
HTML guide for delegated permission, callback, secret and encrypted-state setup.

## Historical initial release

Source: [plugin README](../README.md).
Organization identifier: `com.paytech`.
Ruby namespace: `Paytech::RedmineMicrosoft365Smtp`.
Deliverable: `dist/redmine_microsoft365_smtp-1.0.0.zip`.

Initial release prepared on 22 October 2026. Outbound Microsoft 365 application
authentication over SMTP XOAUTH2; no external automation/proxy dependency,
incoming mail or ticket creation. Default disabled. Credentials supplied through
a private service file or environment variable, never bundled.

Inspected versions: Redmine 7.0.2, Rails 8.1.4, Ruby 4.0.6, Mail 2.9.1,
net-smtp 0.5.2. Isolated tests on target bundle: 35 tests / 136 assertions,
zero failures/errors/skips. Local TLS SMTP test only; no real Microsoft sends.
A separate read-only native Redmine runner registered the plugin and controller
successfully with disabled state. No production installation or service restart.

See plugin documentation/verification.md for coverage and pending live checks.
The reusable package generator is `tools/package.ps1`. Unit tests remain
with source; remote temporary validation artifacts can be removed after testing.
