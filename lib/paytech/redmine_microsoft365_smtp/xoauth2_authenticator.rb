# frozen_string_literal: true

module Paytech::RedmineMicrosoft365Smtp
  # net-smtp 0.5.x exposes this extension API; register a unique name without
  # changing the built-in PLAIN/LOGIN handlers or monkey-patching SMTP globally.
  class Xoauth2Authenticator < Net::SMTP::Authenticator
    auth_type :redmine_m365_xoauth2

    def auth(user, secret)
      unless user.is_a?(String) && secret.is_a?(String) &&
             !user.match?(/[\s\x00-\x1f\x7f]/) && !secret.match?(/[\s\x00-\x1f\x7f]/)
        raise ArgumentError, 'Invalid XOAUTH2 credentials'
      end
      payload = base64_encode("user=#{user}\x01auth=Bearer #{secret}\x01\x01")
      response = smtp.get_response("AUTH XOAUTH2 #{payload}")
      # SASL failure challenges must be terminated before abandoning the session.
      smtp.get_response('') if response.continue?
      raise Net::SMTPAuthenticationError, 'XOAUTH2 authentication rejected' unless response.success?
      response
    end
  end
end
