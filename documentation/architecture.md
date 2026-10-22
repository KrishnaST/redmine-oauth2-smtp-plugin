# Architecture — version 2

`com.paytech` is the organization identifier. Ruby code lives under
`Paytech::RedmineMicrosoft365Smtp`; plugin ID remains `redmine_microsoft365_smtp`.

- Configuration validates GUIDs, headers, timeouts and fixed-purpose HTTPS callback.
- BrowserConnection requests delegated SMTP.Send/offline_access with S256 PKCE.
  An admin/sudo/CSRF POST starts a ten-minute attempt. A random state is bound to
  the existing session; the private store binds its digest, verifier, admin ID,
  settings fingerprint and expiry. Callback requires an existing admin login,
  consumes the attempt before exchange, and performs SMTP AUTH without a message.
  PKCE is mandatory. There is no user-controlled token/authorize host or return URL.
- GrantStore encrypts grants/pending state with AES-256-GCM and a purpose-derived
  Redmine key. Private permissions, no-follow opens, atomic fsynced replacement and
  a stable flock serialize connect/disconnect/rotation across local processes.
- TokenProvider uses authorization_code or refresh_token only, at the fixed
  tenant Microsoft HTTPS endpoint. It checks delegated scope and token expiry.
  Stored tokens are bound to tenant/client/mailbox/callback; changes require
  reconnect. Rotated refresh tokens are persisted before sending.
- DeliveryMethod/Interceptor retain native Redmine recipient selection, MIME,
  Bcc handling, sender enforcement and STARTTLS/XOAUTH2. Disabled plugin leaves
  the existing transport unchanged; enabled failures do not fall back.
- Controller keeps admin/test boundaries, sets no-store/no-referrer and exposes
  no tokens. Connect/disconnect/test use CSRF POST + sudo. Query callback preserves
  Lax cookies; callback query strings must be suppressed in proxy/access logging.

No new database schema, gem, Graph permission or external broker. This is SMTP
authorization, not OpenID/Redmine login. The configured mailbox is checked by
SMTP authentication, not by trusting unverified token claims. A real send remains
necessary to verify Send As, delivery and tenant operational policies.

No background auto-refresh daemon; refresh happens on delivery under the file
lock. One installation-wide grant/pending attempt is supported. Concurrent
administrators must coordinate; newest connect supersedes previous connect.
Disconnect is serialized with connect and invalidates pending attempts. Already
in-flight SMTP sends cannot be recalled by disconnect.
