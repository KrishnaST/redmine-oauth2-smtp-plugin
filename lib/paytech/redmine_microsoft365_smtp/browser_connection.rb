# frozen_string_literal: true

module Paytech::RedmineMicrosoft365Smtp
  class BrowserConnection
    def initialize(store: GrantStore.current, tokens: TokenProvider.instance,
                   clock: -> { Time.now.to_i }, smtp_factory: -> { Net::SMTP.new('smtp.office365.com', 587) })
      @store = store
      @tokens = tokens
      @clock = clock
      @smtp_factory = smtp_factory
    end

    def start(configuration, session:, user_id:)
      configuration.validate_browser!
      state = SecureRandom.urlsafe_base64(32)
      verifier = SecureRandom.urlsafe_base64(64)
      @store.synchronize do |document, save|
        document['pending'] = { 'state_hash' => Digest::SHA256.hexdigest(state), 'verifier' => verifier,
                                'user_id' => user_id.to_s, 'expires_at' => @clock.call + 600,
                                'identity' => configuration.connection_identity }
        save.call(document)
      end
      session[:m365_oauth_state] = state
      query = URI.encode_www_form('client_id' => configuration.client_id, 'response_type' => 'code',
                                  'redirect_uri' => configuration.redirect_uri, 'response_mode' => 'query',
                                  'scope' => TokenProvider::SCOPE, 'state' => state, 'prompt' => 'select_account',
                                  'login_hint' => configuration.mailbox, 'code_challenge_method' => 'S256',
                                  'code_challenge' => Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false))
      "https://login.microsoftonline.com/#{configuration.tenant_id}/oauth2/v2.0/authorize?#{query}"
    end

    def finish(configuration, session:, user_id:, state:, code:, denied: false)
      expected = session.delete(:m365_oauth_state).to_s
      unless state.is_a?(String) && expected.bytesize == 43 && state.bytesize == 43 &&
             OpenSSL.fixed_length_secure_compare(expected, state)
        raise ConfigurationError, 'INVALID_OAUTH_STATE'
      end
      @store.synchronize do |document, save|
        pending = document.delete('pending')
        save.call(document) # Consume before exchange, including denied/error callbacks.
        unless pending && pending['state_hash'] == Digest::SHA256.hexdigest(state) &&
               pending['user_id'] == user_id.to_s && pending['expires_at'].to_i > @clock.call &&
               pending['identity'] == configuration.connection_identity
          raise ConfigurationError, 'OAUTH_ATTEMPT_EXPIRED_OR_CHANGED'
        end
        raise ConfigurationError, 'MICROSOFT_CONSENT_DENIED' if denied
        unless code.is_a?(String) && !code.empty? && code.bytesize <= 16_384 && !code.match?(/[\r\n\x00]/)
          raise ConfigurationError, 'INVALID_AUTHORIZATION_CODE'
        end
        grant = @tokens.exchange_code(configuration, code: code, verifier: pending.fetch('verifier'))
        authenticate_mailbox!(configuration, grant.fetch('access_token'))
        document['grant'] = grant
        save.call(document)
      end
    end

    def disconnect
      @store.synchronize { |_document, save| save.call({}) }
    end

    def connected?(configuration)
      @store.synchronize do |document, _save|
        document.dig('grant', 'identity') == configuration.connection_identity
      end
    end

    private

    # Establish mailbox authorization without submitting MAIL, RCPT or DATA.
    # This is not used as a Redmine login or an assertion of user identity.
    def authenticate_mailbox!(configuration, access_token)
      smtp = @smtp_factory.call
      context = OpenSSL::SSL::SSLContext.new
      context.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
      context.min_version = OpenSSL::SSL::TLS1_2_VERSION
      smtp.enable_starttls(context)
      smtp.open_timeout = configuration.open_timeout
      smtp.read_timeout = configuration.read_timeout
      smtp.start(configuration.helo_domain, configuration.mailbox, access_token, :redmine_m365_xoauth2) { |_connection| nil }
    rescue StandardError
      raise DeliveryError, 'MAILBOX_AUTHORIZATION_FAILED', cause: nil
    end
  end
end
