# Redmine Microsoft 365 SMTP OAuth2

[Open the HTML installation and configuration guide](documentation/installation-configuration.html).

Outbound-only Microsoft 365 delivery for Redmine's existing notifications.
No external automation service, SMTP proxy, inbound mailbox processing or ticket
creation. Version 1.0.0; disabled by default.

Organization identifier: `com.paytech`. Ruby namespace:
`Paytech::RedmineMicrosoft365Smtp`; Redmine plugin ID and installation directory:
`redmine_microsoft365_smtp`. Ruby has no Java-style dotted package declarations.

## Compatibility

Target inspected on 22 October 2026: Redmine 7.0.2, Rails 8.1.4, Ruby 4.0.6,
Mail 2.9.1 and net-smtp 0.5.2. This plugin requires net-smtp's Authenticator
extension API and supplies its own uniquely named XOAUTH2 authenticator.
It adds no new production gems or database tables. Other Redmine versions are
not claimed to be verified. Tests use the target's installed gems in isolation.

## How it works

An Action Mailer interceptor selects this delivery method when the plugin is
enabled. Existing recipient selection, issue permissions and notification
preferences remain Redmine's responsibility. The same method receives messages
when jobs are actually delivered, including previously assembled messages.

The plugin requests an application token from Microsoft's tenant-specific
endpoint and submits MIME mail through smtp.office365.com:587 with required
STARTTLS, certificate verification and XOAUTH2. Tokens exist only in process
memory, cached with an expiry margin and synchronized across threads. Separate
workers obtain separate client-credentials tokens; there are no refresh tokens
to rotate. Client-secret changes invalidate the process-local token cache.

The From address and SMTP envelope sender are set to the configured mailbox.
The display name is configurable. Reply-To, To, Cc, Bcc and MIME attachments are
preserved by the Mail gem; Bcc recipients are not exposed in the message headers.
This prevents accidental unauthorized Send As addresses. Disable Redmine's
author-as-sender behavior if it conflicts with your expected presentation.

Once enabled, a configuration/token/SMTP error fails closed: there is no fallback
to username/password SMTP and no automatic resend after SMTP DATA. Follow
Redmine's job delivery/retry and failure monitoring procedures; submission is
not a guarantee of inbox delivery. SMTP concurrency across workers must respect
Microsoft mailbox limits. Configure queues accordingly.

## Microsoft setup (performed by your Microsoft 365 administrator)

1. Create a dedicated single-tenant Entra application for Redmine.
2. Grant Office 365 Exchange Online application permission `SMTP.SendAsApp`
   and obtain administrator consent. Microsoft Graph Mail.Send is not used.
3. Register the enterprise application's service principal in Exchange Online.
   Use the Enterprise Application Object ID, not the App Registration Object ID.
4. Grant only the intended sending mailbox's required Exchange access and Send As
   permissions. Validate mailbox scoping before production use; do not grant
   organization-wide mailbox access for convenience.
5. Ensure tenant/mailbox policies permit OAuth SMTP AUTH. Do not weaken tenant
   security defaults solely to enable Basic authentication.
6. Create a client secret, record its expiry and arrange rotation. This initial
   version supports client-secret credentials, not certificate assertions or
   delegated browser sign-in.

Follow Microsoft's current administrator instructions, including the distinction
between Entra and Exchange service-principal IDs:
[OAuth SMTP application authentication](https://learn.microsoft.com/en-us/exchange/client-developer/legacy-protocols/how-to-authenticate-an-imap-pop-smtp-application-by-using-oauth).

## Installation (not performed automatically)

Clone the source repository into your preferred development directory.
Run `./tools/package.ps1` from PowerShell to generate
`dist/redmine_microsoft365_smtp-1.0.0.zip`. The archive always uses the required
`redmine_microsoft365_smtp/` installation directory, independent of the source
repository name. Git metadata and build outputs are excluded.

1. Test in a non-production Redmine instance first. Back up configuration and
   deploy during an approved change window.
2. Extract this folder as `plugins/redmine_microsoft365_smtp` in Redmine.
   The exact directory name must match the plugin ID.
3. No `redmine:plugins:migrate` command is needed; this plugin has no migrations.
4. Configure the credential in the Redmine web AND background-worker service
   environments; see below. Keep the old SMTP configuration for rollback.
5. Restart the affected Redmine web/worker processes through your normal service
   procedure. Installation alone does not enable this plugin.
6. In Administration > Plugins > Microsoft 365 SMTP OAuth2 > Configure, enter
   tenant GUID, client GUID, sending mailbox, sender name and EHLO domain.
   Timeouts are integer seconds from 1 to 120.
7. Save with Enable Microsoft 365 SMTP checked only when prerequisites are ready.
8. Open the linked test page and explicitly send one test to your administrator
   account's own primary email address. The action requires administrator access,
   a POST with a valid CSRF token and Redmine sudo-mode reauthentication when
   sudo mode is enabled. No other recipient can be passed to the action.
9. Verify arrival, then an authorized ordinary ticket-notification test. Confirm
   permission-based recipients, Bcc behavior, attachments and queue operation.

Examples use `/opt/redmine`, service `redmine.service` and service account
`redmine`. Substitute your actual deployment paths and account. Building or
running isolated tests does not install or enable the plugin.

## Credentials and environment variables

| Variable | Purpose |
| --- | --- |
| `REDMINE_M365_CLIENT_SECRET_FILE` | Preferred: absolute path to a UTF-8 file containing only the Entra client-secret value. Linux owner must be the service user or root, permissions must deny group/other access (0600 or stricter), regular file only, up to 4096 bytes. Symlinks are rejected. |
| `REDMINE_M365_CLIENT_SECRET` | Alternative client-secret value from the service environment. Never put this in source control, logs or a command-line argument. |

The file takes precedence. If the file is invalid or unreadable, the plugin does
not fall back to the environment value. Both variables are optional while the
plugin is disabled. Protect parent directories and prevent unauthorized writes.
Use your service manager's approved secret provisioning; do not put secrets into
the plugin settings database, emails or screenshots. Rotation changes the file
contents or environment; environment changes require worker restarts. Maintain
two overlapping Entra secrets during an approved rotation if required.

No credential is bundled. Nonsecret plugin settings are stored in Redmine's
existing Setting mechanism. The plugin never records tokens, message bodies,
recipients or provider error bodies in logs. Existing Redmine/SMTP diagnostic
logging should also be checked to ensure it does not reveal sensitive content.

## Operational dependencies and endpoints

- Outbound HTTPS 443: `login.microsoftonline.com`, tenant-specific token endpoint.
- Outbound SMTP 587: `smtp.office365.com`, mandatory STARTTLS.
- Trusted system CA store, DNS and accurate server time.
- Microsoft 365 sending mailbox, scoped Exchange service principal and Entra
  application described above. Mailbox/subscription limits still apply.
- Administrator GET/POST endpoint: `/admin/microsoft365_smtp/test`, under your
  configured Redmine prefix if any. Does not expose OAuth tokens or secrets.
- Settings endpoint: Redmine's normal `/settings/plugin/redmine_microsoft365_smtp`.

## Rollback

Uncheck Enable Microsoft 365 SMTP and save. Redmine's original configured
delivery transport is then used for newly delivered messages. If the plugin is
removed, restart all Redmine web and worker processes. No data migration is
required. Disable/revoke its Microsoft application credential when retired.
Do not delete notification jobs or incoming tickets as part of installation.

## Verification

From the Redmine root using its installed bundle:

```sh
bundle exec ruby plugins/redmine_microsoft365_smtp/test/run.rb
```

Tests use fake HTTPS transports, fake/loopback-only SMTP servers, fictitious
credentials and temporary secret files. They do not connect to Microsoft, send
real emails or require database access. Controller tests use isolated stand-ins
for Redmine's authentication/sudo hooks; native Redmine integration is separately
checked in a read-only runner process. No production service is restarted.
See [verification status](documentation/verification.md) for actual results and
remaining production checks. No real delivery is claimed until the administrator
has configured Microsoft and explicitly run an end-to-end test.

## References

- [Documentation index](documentation/README.md)
- [Redmine plugin tutorial](https://www.redmine.org/projects/redmine/wiki/Plugin_Tutorial)
- [Microsoft OAuth SMTP](https://learn.microsoft.com/en-us/exchange/client-developer/legacy-protocols/how-to-authenticate-an-imap-pop-smtp-application-by-using-oauth)
