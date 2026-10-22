# frozen_string_literal: true

module Paytech::RedmineMicrosoft365Smtp
  class TokenProvider
    SCOPE = 'https://outlook.office.com/SMTP.Send offline_access'

    def self.instance
      @instance ||= new
    end

    def initialize(http_factory: ->(host, port) { Net::HTTP.new(host, port, nil) },
                   store_provider: -> { GrantStore.current }, clock: -> { Time.now.to_i })
      @http_factory = http_factory
      @store_provider = store_provider
      @clock = clock
    end

    def access_token(configuration)
      configuration.validate_browser!
      @store_provider.call.synchronize do |document, save|
        grant = document['grant']
        unless grant && grant['identity'] == configuration.connection_identity
          raise TokenError, 'MICROSOFT_RECONNECT_REQUIRED'
        end
        return grant.fetch('access_token') if grant['expires_at'].to_i > @clock.call + 60
        replacement = request_token(configuration, 'grant_type' => 'refresh_token', 'refresh_token' => grant.fetch('refresh_token'))
        replacement['refresh_token'] ||= grant.fetch('refresh_token')
        document['grant'] = replacement
        save.call(document)
        replacement.fetch('access_token')
      end
    end

    def exchange_code(configuration, code:, verifier:)
      grant = request_token(configuration, 'grant_type' => 'authorization_code', 'code' => code,
                            'code_verifier' => verifier, 'redirect_uri' => configuration.redirect_uri)
      raise TokenError, 'REFRESH_TOKEN_REQUIRED' unless grant['refresh_token']
      grant
    end

    def invalidate!
      @store_provider.call.synchronize do |document, save|
        return unless document['grant']
        document['grant']['expires_at'] = 0
        save.call(document)
      end
    end

    def inspect
      '#<Paytech::RedmineMicrosoft365Smtp::TokenProvider [REDACTED]>'
    end

    private

    def request_token(configuration, fields)
      configuration.validate_browser!
      started = @clock.call
      uri = URI("https://login.microsoftonline.com/#{configuration.tenant_id}/oauth2/v2.0/token")
      http = @http_factory.call(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.min_version = OpenSSL::SSL::TLS1_2_VERSION
      http.open_timeout = configuration.open_timeout
      http.read_timeout = configuration.read_timeout
      http.write_timeout = configuration.read_timeout
      request = Net::HTTP::Post.new(uri.request_uri)
      request.set_form_data(fields.merge('client_id' => configuration.client_id, 'client_secret' => configuration.client_secret, 'scope' => SCOPE))
      raw = +''
      response = http.request(request) do |incoming|
        incoming.read_body do |chunk|
          raw << chunk
          raise TokenError, 'INVALID_TOKEN_RESPONSE' if raw.bytesize > 65_536
        end
      end
      raise TokenError, 'MICROSOFT_RECONNECT_REQUIRED' if response.code.to_i == 400
      raise TokenError, "TOKEN_HTTP_#{response.code.to_i}" unless response.is_a?(Net::HTTPSuccess)
      body = JSON.parse(raw)
      access = body['access_token']
      refresh = body['refresh_token']
      lifetime = Integer(body.fetch('expires_in'))
      scopes = body['scope'].to_s.split
      unless body['token_type'].to_s.casecmp?('Bearer') && access.is_a?(String) && !access.empty? &&
             !access.match?(/[\r\n\x00]/) && lifetime.between?(120, 86_400) &&
             scopes.any? { |scope| scope.casecmp?('https://outlook.office.com/SMTP.Send') || scope.casecmp?('https://outlook.office365.com/SMTP.Send') }
        raise TokenError, 'INVALID_TOKEN_RESPONSE'
      end
      if refresh && (!refresh.is_a?(String) || refresh.empty? || refresh.match?(/[\r\n\x00]/))
        raise TokenError, 'INVALID_TOKEN_RESPONSE'
      end
      { 'identity' => configuration.connection_identity, 'access_token' => access,
        'refresh_token' => refresh, 'expires_at' => started + lifetime }
    rescue Error
      raise
    rescue JSON::ParserError, KeyError, ArgumentError, TypeError
      raise TokenError, 'INVALID_TOKEN_RESPONSE', cause: nil
    rescue StandardError
      raise TokenError, 'TOKEN_CONNECTION_FAILED', cause: nil
    end
  end
end
