# Simplified settings — 2.0.2

Keep Enable, Connect Microsoft, tenant/client IDs, sending mailbox and sender name.
The application identity and mailbox are genuinely needed by the current flow;
they are not silently replaced, hidden as fake defaults or embedded in public code.

Removed callback, EHLO and timeout inputs. Live Configuration.current derives
callback/EHLO from trusted Redmine protocol, public hostname and configured URL
prefix, never from incoming request headers. Callback remains visible read-only
for Entra registration. HTTPS is mandatory; timeouts use 15/30 seconds.
Existing obsolete per-plugin values are ignored; no database cleanup is needed.
Public URL changes require reconnecting and updating the Entra Web callback.

Shortened UI instructions; private secret/state provisioning remains documented
in README/installation guide. This does not fix a mismatched application identity
by itself: the separately created Entra client and matching secret still need to
be deliberately applied. No Graph mailbox discovery was added.
