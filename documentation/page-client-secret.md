# Page-managed client secret — 2.0.3

Enter the Entra client-secret **Value** in the masked Client secret field on the
same plugin settings page as the tenant/client IDs, then click the normal Save.
The field is always blank on render. Blank preserves the existing encrypted
value. Remove page-managed secret clears that value and restores any server-file
or environment fallback. Clear and replace in the same request is rejected.

The native Redmine SettingsController admin, sudo-mode and CSRF callbacks run
before an action extension handles the secret. Plaintext is removed from request
settings before native persistence. The service encrypts using AES-256-GCM with a
purpose-separated key derived from Redmine's secret_key_base. Only ciphertext is
stored in the existing plugin Setting row; no new schema or migration. Submitted
ciphertext is ignored. Log filters cover the plaintext field. The interface never
prepopulates plaintext or ciphertext and reports only whether a page value exists.

Precedence: encrypted page value, then configured secret file, then environment.
A corrupt/unreadable encrypted page value fails closed without fallback.
Protect database backups and the Redmine encryption secret separately. All web
and worker processes must use the same stable key. Key loss/rotation requires
re-entering the secret and reconnecting OAuth. Plugin source contains no client
credential. Changing credentials does not grant Microsoft consent or enable mail.

This release does not automatically apply the previously generated application
credentials or deploy the plugin. Save the matching client ID and secret together
before connecting. Use HTTPS and keep proxy/body logging disabled for settings.
