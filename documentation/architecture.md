# Architecture and security

Organization identifier: `com.paytech`; Ruby namespace:
`Paytech::RedmineMicrosoft365Smtp`. Implementation files follow Ruby's namespace
layout under `lib/paytech/`. The Redmine plugin ID remains
`redmine_microsoft365_smtp`; the dotted organization identifier is not a Java
package declaration or a Redmine installation-directory name.

1. Redmine assembles a notification with its normal recipient and permission logic.
2. Interceptor reads the enabled flag at delivery time; disabled means untouched.
3. DeliveryMethod validates configuration and asks TokenProvider for a token.
4. TokenProvider reads the private service credential and requests a scoped
   client-credentials token from Microsoft's fixed commercial-cloud endpoint.
5. The SMTP transport requires verified TLS and authenticates using the plugin's
   namespaced net-smtp Authenticator implementation of Microsoft's SASL format.
6. Mail::SMTPConnection handles validated envelope addresses and encoded MIME data.

No core Redmine source is patched. The plugin does not create database tables,
expose a public callback, process incoming mail or fetch a Microsoft mailbox.
The only interactive action sends a static test email to the signed-in admin.
Settings use Redmine's existing administrator-only plugin configuration surface.

Application credentials are injected at runtime. Token cache is in-memory only,
has an expiry margin and is keyed by tenant/client and credential digest. Changes
to the credential force a new token. Concurrent token refresh is synchronized
within each process. Multiple processes do not share a refresh token or a disk
token cache. Cache values and credentials have redacted object inspection.

Provider exceptions are converted into bounded, non-sensitive error codes;
SMTP/TLS response bodies and nested exception causes are not surfaced. The
plugin does not bypass TLS, downgrade authentication, follow token redirects,
or retry a potentially accepted SMTP message. Errors remain visible to Redmine's
normal delivery monitoring. Keep separate web/worker concurrency within the
mailbox's SMTP session limits.

Limitations: client-secret application flow only; global outgoing transport,
one Microsoft 365 mailbox; commercial cloud endpoints; no Graph transport,
delegated OAuth UI, certificate assertion, incoming email or per-project sender.
Changes to configuration are validated at send time, not by Redmine's generic
settings persistence. Enable only after checking prerequisites and testing.
