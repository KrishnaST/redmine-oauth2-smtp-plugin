# Direct Connect Microsoft button — 2.0.1

Following the reference email sender UX, the plugin settings page offers a blue
Connect Microsoft button that posts directly to the existing connect endpoint.
No additional connection page is required. Save settings first: unsaved fields
are not stored by this button. The separate status/disconnect page remains.

Uses native Redmine `link_to method: :post`, as in its existing account views.
Redmine UJS generates a CSRF-protected form outside the enclosing settings form;
no nested form, insecure GET or new production dependency is introduced. Existing
admin, sudo-mode, one-use state and S256 PKCE protections remain unchanged.

The button does not automatically discover the Microsoft mailbox, enable delivery
or send email. The administrator still completes Microsoft sign-in, MFA and any
required consent. This change does not apply newly created Entra credentials.
