# Browser OAuth troubleshooting

Never paste tokens, client secrets, authorization codes or provider bodies into logs.

| Safe code | Action |
| --- | --- |
| INVALID_REDIRECT_URI | Save exact HTTPS Web callback, no query/fragment/userinfo; include actual Redmine prefix. |
| INVALID_OAUTH_STATE | Use same logged-in admin browser session; restart Connect. Do not replay old callback URLs. |
| OAUTH_ATTEMPT_EXPIRED_OR_CHANGED | Attempt expired, superseded, cancelled, disconnected, or settings/admin changed. Start again. |
| MICROSOFT_CONSENT_DENIED | Sign-in was cancelled/denied; resolve tenant consent policy, then reconnect. |
| STATE_DIRECTORY_REQUIRED | Configure private durable state directory for every worker. |
| UNSAFE_STATE_DIRECTORY / UNSAFE_STATE_FILE | Correct ownership/0700 directory/0600 files and remove symlink usage through approved operations. |
| STATE_STORE_FAILED | Check filesystem, permissions and stable Redmine secret_key_base. Wrong key/corruption fails closed. Reconnect after securely clearing obsolete state with workers stopped. |
| MICROSOFT_RECONNECT_REQUIRED | Missing/mismatched/expired or revoked grant; reconnect. Microsoft HTTP 400 is deliberately sanitized. |
| REFRESH_TOKEN_REQUIRED | Ensure offline_access consent and confidential Web configuration; reconnect. |
| INVALID_TOKEN_RESPONSE | Check delegated SMTP.Send consent and provider configuration. No application-only fallback exists. |
| TOKEN_HTTP_401 | Verify confidential application's client-secret value and expiry. |
| MAILBOX_AUTHORIZATION_FAILED | Resolve OAuth SMTP AUTH and mailbox permissions/policies; sign in with intended account. No message was sent by Connect. |
| SMTP_AUTH_REJECTED | Check mailbox SMTP AUTH policy and grant; reconnect if revoked. |

Connection status means a locally stored matching grant, not proof it remains
unrevoked. Refresh/delivery can still require reconnect later. New connections
stay disabled until explicitly enabled by an administrator. Disconnect also
disables the plugin, but Microsoft-side grant revocation is a separate action.

If callback login session is lost, inspect HTTPS/proxy/cookie/SameSite settings.
Do not turn off CSRF protections or change cookie policy blindly. Exclude callback
query strings from gateway/Tomcat/proxy/APM logs before enabling the flow.
