# Paytech Redmine Microsoft 365 SMTP OAuth2

Version **2.0.3**: delegated Microsoft browser authorization with **S256 PKCE**.
The settings page includes a direct **Connect Microsoft** button, like the
reference email sender. Save settings, then click once to open Microsoft sign-in.
Native Redmine UJS uses a CSRF-protected POST, not a state-changing GET or nested form.
Organization identifier `com.paytech`; Ruby namespace
`Paytech::RedmineMicrosoft365Smtp`. Plugin ID/folder remains
`redmine_microsoft365_smtp`.

[HTML installation guide](documentation/installation-configuration.html) ·
[Documentation index](documentation/README.md)

## Scope and compatibility

Outbound native Redmine notifications only. No incoming mail, ticket creation,
proxy service or new production gems. Target: Redmine 7.0.2, Rails 8.1.4,
Ruby 4.0.6, Mail 2.9.1, net-smtp 0.5.2 on Linux. Other versions are unverified.
Disabled by default. **Version 2 replaces version 1 application-only authentication**;
existing settings require an HTTPS callback and a new interactive connection.
There is no client-credentials or password fallback.

## Microsoft prerequisites

1. Register a single-tenant confidential **Web** application in Microsoft Entra.
2. Configure delegated `https://outlook.office.com/SMTP.Send`; the plugin also
   requests `offline_access` for renewal. Grant consent according to tenant policy.
   `SMTP.SendAsApp`, Graph `Mail.Send`, Graph `User.Read`, implicit grant and
   public-client/device-code flows are not required by this implementation.
3. Add the exact HTTPS Web redirect URI:
   `https://redmine.example.com/admin/microsoft365_smtp/callback`.
   Include any actual Redmine URL prefix. Do not register it as an SPA callback.
4. Create a client secret, record its expiry and arrange rotation. Keep it out of Git.
5. Permit OAuth SMTP AUTH for the intended mailbox and sign-in under tenant/MFA
   policies. Do not weaken tenant security controls merely to force SMTP access.

The administrator signs into Microsoft as the intended sending mailbox. This
authorizes mail submission, **not Redmine login**. Connecting probes SMTP AUTH
for the configured mailbox without sending a message. It does not assert the
Microsoft account's identity through Graph/OIDC, nor guarantee Send As/inbox
delivery. An authorized real test is required before enabling ordinary traffic.

## Installation and upgrade

1. Package with `./tools/package.ps1` in PowerShell. Output:
   `dist/redmine_microsoft365_smtp-2.0.3.zip`.
2. Disable any installed version first. Deploy during an approved change window.
   Replace the whole plugin directory, not individual files; preserve private
   operational secrets outside the plugin tree. No migrations are needed.
3. Extract the canonical archive folder under `/opt/redmine/plugins/`.
4. Enter the client-secret Value on the plugin settings page (saved encrypted),
   or optionally provision a private secret file. Provision a durable state directory for the service
   account, e.g. `/etc/redmine/secrets/m365-client-secret` (0600) and
   `/var/lib/redmine-m365` (0700). The state directory must be owned by the
   service account, absolute, not symlinked or web-served. Its ancestors must not
   be writable by untrusted accounts. Do not use tmp/cache directories.
5. Configure the variables below in **all** web/worker service environments.
   Set a stable Redmine `secret_key_base` shared by those processes. Grant files
   use purpose-separated AES-256-GCM encryption derived from that secret.
6. Prevent callback query-string logging in reverse proxy, web access logs, APM
   and analytics. Do not enable HTTP/SMTP debug/body logging. Rails filters
   `code`, `state`, `error_description`, client secrets and tokens. Query-mode
   callback needs the same logged-in administrator session (SameSite=Lax cookie).
7. Restart Redmine web/workers. Save tenant/client GUIDs, mailbox and
   sender name in Administration → Plugins →
   Microsoft 365 SMTP OAuth2 → Configure, **while disabled**.
   The callback URI is displayed read-only and derived from trusted Redmine
   Administration → Settings public hostname/protocol and application URL prefix.
   EHLO uses that hostname; timeouts are 15/30 seconds. Obsolete per-plugin
   callback/EHLO/timeout values are ignored. HTTPS is required.
8. Click **Connect Microsoft** directly on the settings page (or Connect/reconnect
   on the connection page), complete
   Microsoft sign-in/MFA/consent, then return to the same Redmine admin session.
   The newest attempt replaces earlier attempts; attempts expire after 10 minutes.
9. Enable only when ready, then explicitly send one test to the signed-in
   Redmine administrator's primary email using the existing test page. Confirm
   arrival and normal authorized notification behavior. Connecting alone never
   enables the plugin or sends email.

Examples are generic: substitute actual installation paths and service identity.
Do not copy a client secret into shell history, command-line arguments or docs.

## Environment variables

| Variable | Purpose |
| --- | --- |
| `REDMINE_M365_CLIENT_SECRET_FILE` | Optional fallback when no page secret exists: regular non-symlink file, root/service owner, mode 0600 or stricter, maximum 4096 bytes. Contains only the Entra client-secret value. |
| `REDMINE_M365_CLIENT_SECRET` | Alternative runtime secret; not used if a secret-file path is configured, even if that file is invalid. |
| `REDMINE_M365_STATE_DIRECTORY` | Required private durable 0700 directory owned by service account. Encrypted `grant.enc` and 0600 cross-process `grant.lock`. Shared by web/workers on the same host. |

No tokens are stored in Redmine plugin settings. The encrypted state includes
refresh/access tokens and pending PKCE authorization. Do not expose or export it.
Back up the state together with the Redmine encryption secret using approved
secret-handling controls; losing/rotating `secret_key_base` requires reconnecting.
Do not delete a lock file while workers are active. This file store supports one
host/shared local filesystem, not independent multi-host state copies.

The masked Client secret field saves AES-256-GCM ciphertext in the existing
plugin Setting row, using a purpose-separated Redmine encryption key. Blank
preserves; Remove page-managed secret clears it and restores server fallback.
The page value takes precedence over file/environment. Corrupt ciphertext fails
closed, never falls back. See [page secret reference](documentation/page-client-secret.md).

## Endpoints and network dependencies

All routes require a Redmine administrator. Connect, disconnect and test are
CSRF-protected POSTs with Redmine sudo-mode hooks. Callback is a state-checked
GET; it never authenticates users into Redmine. Responses are no-store and
no-referrer.

| Method | Endpoint | Purpose |
| --- | --- | --- |
| GET | `/admin/microsoft365_smtp/connection` | Local connection status |
| POST | `/admin/microsoft365_smtp/connect` | Start Microsoft browser authorization |
| GET | `/admin/microsoft365_smtp/callback` | Consume one-use authorization result |
| POST | `/admin/microsoft365_smtp/disconnect` | Clear local grant/pending attempt and disable plugin |
| GET/POST | `/admin/microsoft365_smtp/test` | Form / send one email to current admin only |

Requires DNS, accurate time, trusted system CAs, outbound HTTPS 443 to
`login.microsoftonline.com` and SMTP 587 to `smtp.office365.com`. SMTP requires
STARTTLS with peer/hostname verification and TLS 1.2+. There is no Graph dependency.

## Lifecycle, rollback and testing

Changing tenant, client, mailbox or callback requires reconnecting. Secret rotation
does not discard the grant but the new confidential-client secret must be valid.
Refresh-token replacements are encrypted and durably saved under an exclusive
file lock before SMTP submission. Failed/invalid grants require reconnecting;
no password fallback or retry after SMTP DATA is attempted. Failures are sanitized.

Disconnect removes local tokens and disables the plugin. It does not revoke the
Microsoft grant: revoke it in Entra when retiring access. Unchecking Enable
restores Redmine's original configured transport for newly delivered messages.
Removing the plugin requires restarting web/workers; no migrations are needed.
Version 1 rollback also requires restoring its earlier settings deliberately.

Run against Redmine's installed bundle from its root:

```sh
bundle exec ruby plugins/redmine_microsoft365_smtp/test/run.rb
```

Tests use fictitious credentials, fake Microsoft HTTP and loopback-only SMTP,
not real Microsoft delivery. See [verification](documentation/verification.md)
for actual results and limitations. No deployment is implied by building a ZIP.

## References

- [Microsoft authorization code + PKCE](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow)
- [Microsoft delegated SMTP OAuth](https://learn.microsoft.com/en-us/exchange/client-developer/legacy-protocols/how-to-authenticate-an-imap-pop-smtp-application-by-using-oauth)
- [SMTP AUTH policy](https://learn.microsoft.com/en-us/exchange/clients-and-mobile-in-exchange-online/authenticated-client-smtp-submission)
