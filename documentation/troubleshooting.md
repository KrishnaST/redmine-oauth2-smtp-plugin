# Troubleshooting

| Code | Check |
| --- | --- |
| `INVALID_TENANT_ID`, `INVALID_CLIENT_ID` | Use actual GUIDs; `organizations` is not valid for application credentials. |
| `INVALID_MAILBOX`, `INVALID_SENDER_NAME`, `INVALID_HELO_DOMAIN` | Review settings; control characters are rejected. |
| `INVALID_TIMEOUT` | Integer seconds between 1 and 120. |
| `MISSING_CLIENT_SECRET` | Set one documented service environment variable. |
| `UNSAFE_SECRET_FILE`, `SECRET_FILE_UNREADABLE` | Regular file, owner service user/root, no group/other permissions, readable by service, protected directory, no symlink. |
| `TOKEN_HTTP_400`, `TOKEN_HTTP_401`, `TOKEN_HTTP_403` | Check tenant, application credential expiry, admin consent and Exchange application permission. Inspect Entra sign-in diagnostics through an authorized admin; do not log the secret or token. |
| `TOKEN_HTTP_429` | Microsoft throttling. Review job rate and service policy before retrying. |
| `INVALID_TOKEN_RESPONSE` | Token endpoint did not supply a usable Bearer token and positive expiry. |
| `TOKEN_CONNECTION_FAILED` | DNS, outbound 443, trust store or network timeout. |
| `SMTP_AUTH_REJECTED` | SMTP AUTH policy, correct Enterprise Application service principal, mailbox scope and Send As rights. No fallback to Basic authentication. Cache is invalidated; message is not resent automatically. |
| `SMTP_TLS_FAILED` | CA trust, server hostname and TLS connectivity. Do not disable verification. |
| `SMTP_TEMPORARY_FAILURE` | SMTP server busy/throttling. Follow the job queue's reviewed retry policy. |
| `SMTP_DELIVERY_FAILED` | Connection, recipient/envelope, unsupported SMTP operation or rejected message. Check authorized provider traces and queue status without enabling credential/MIME debug logging. |
| `PLUGIN_DISABLED` | Save settings with enabled selected before running plugin's test. |

The test page reports SMTP acceptance only. Delivery can still fail afterward;
check Microsoft message trace and the intended inbox for end-to-end validation.
