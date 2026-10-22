# Verification status

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
