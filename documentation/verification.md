# Verification status

## Version 2.0.2 — simplified settings

2026-10-22: 53 tests / 251 assertions, zero failures/errors/skips, seed 16491,
against the target bundle in isolation. Native read-only boot/rendering passed.
Regression checks cover removal of callback/EHLO/timeout inputs, trusted public
URL callback derivation with port/prefix handling, rejection of unsafe origins,
fixed timeout defaults and ignoring obsolete manual values. Whitespace check
passed. No live deployment, settings/credential edits, restart or Microsoft
authorization/email submission was performed for this change.

## Version 2.0.1 — direct Connect Microsoft button

2026-10-22: 51 tests, 235 assertions, zero failures/errors/skips, seed 36631,
against the target's installed bundle in a disposable directory. Native read-only
boot passed, including rendering the settings partial and verifying the direct
connect link's POST data attribute and absence of nested forms. Existing admin,
CSRF, sudo, state and PKCE tests passed. No live plugin deployment/restart,
Microsoft sign-in, credential update or actual message submission was performed.
Browser execution of Redmine UJS remains an end-to-end check after deployment.

## Version 2.0.0 — browser authorization + PKCE

2026-10-22: isolated tests against the installed target bundle passed **50 tests,
229 assertions, zero failures/errors/skips**, seed 28481. No installation,
restart, Microsoft authorization, real token exchange or email delivery for v2.
The initial v2 run exposed three Ruby keyword-vs-positional test-call errors;
explicit hash arguments corrected those fixtures, and the full rerun passed.

Coverage: S256 challenge/verifier exchange, delegated scope, one-use session/admin
state, replay/tamper/expiry/denial/settings-change rejection, disconnect fencing,
SMTP probe failure without grant publication, admin/sudo/CSRF boundaries, actual
controller redirect/callback behavior, no email on connect, encrypted at-rest
state with permissions/symlink/key checks, concurrent serialized updates,
refresh caching/rotation/expiry, persistence-before-return, no scope fallback,
bounded/sanitized HTTP failures, native MIME/Bcc and loopback STARTTLS/XOAUTH2.
Controller tests stand in for Redmine auth/sudo hooks; actual Microsoft browser
and tenant-policy integration remains pending, including callback logging/cookies.

Native v2 read-only boot check passed: `NATIVE_PKCE_BOOT_OK enabled=false`.
Reusable `tools/verify-native.rb` changes plugin discovery only in its own
process and verifies registration, routes, OAuth parameter log filtering,
native connection-view rendering and encrypted-state round-trip with the native
Redmine key generator in a disposable private test directory.
The live plugin directory/service/settings were not changed.

## Historical version 1 checks

Target inspected read-only on 22 October 2026:
Redmine 7.0.2, Rails 8.1.4, Ruby 4.0.6, Mail 2.9.1, net-smtp 0.5.2.

Verification completed on 22 October 2026 against the target's installed bundle,
using an isolated `/tmp` directory (not its live plugins directory):

- 34 tests, 134 assertions, zero failures/errors/skips (random seed 7272).
- Configuration validation, private-file permissions, credential injection guards.
- Client-credentials request shape, HTTPS verification, caching, expiry,
  secret rotation, invalidation, parallel requests, safe provider failures.
- Real net-smtp session to a loopback STARTTLS server with a test-only trust root,
  successful XOAUTH2 and MIME submission; rejection of a server without STARTTLS.
- Envelope recipients/Bcc and attachments; sanitized failures, no unsafe retry.
- Action Mailer registration, repeated initialization without duplicate
  interceptors, default-disabled behavior, admin-only test route contract,
  sudo-hook invocation, CSRF rejection and self-recipient restriction.
- Controller tests stub Redmine's existing auth/sudo hooks; they do not claim
  to exercise a real user's session or production browser sign-in.
- Separate native Redmine runner with `PGOPTIONS=-c default_transaction_read_only=on`
  and explicit `SET TRANSACTION READ ONLY` successfully registered the plugin,
  loaded its real controller, verified default disabled state and registered
  delivery method. Temporary plugin discovery was changed in that process only;
  no application directory, service configuration or database row was changed.

The read-only boot harness initially exposed nested `config.to_prepare`
registration missing initial setup. The entrypoint now registers immediately
inside Redmine's own PluginLoader lifecycle; the repeated-initialization test
guards the correction. Earlier standalone harness path errors were not runtime
delivery failures and did not require installing the plugin.

Microsoft token exchange, SMTP delivery and production plugin activation:
not performed. No Microsoft credentials are bundled or reused from other projects.

The namespace was subsequently moved under Paytech (organization com.paytech).
Revalidation passed: 35 tests, 136 assertions, no failures/errors/skips (seed
23768). This includes an added organization/namespace regression check.
The namespaced implementation also passed a separate native Redmine read-only
initialization check with organization identifier com.paytech and disabled state.
The earlier 34-test result above describes the initial implementation.

Pending after separately authorized installation: plugin settings-page browser
test, real Microsoft consent/mailbox-scoping validation, one explicit test
email, ordinary issue-notification delivery and configured background-worker
queue behavior. Deployment has not been performed.
