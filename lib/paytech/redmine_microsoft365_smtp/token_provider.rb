# frozen_string_literal: true

require 'digest'

module Paytech::RedmineMicrosoft365Smtp
  class TokenProvider
    SCOPE = 'https://outlook.office365.com/.default'

    def self.instance
      @instance ||= new
    end

    def initialize(http_factory: ->(host, port) { Net::HTTP.new(host, port, nil) },
                   clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @http_factory = http_factory
      @clock = clock
      @mutex = Mutex.new
      @token = nil
      @cache_key = nil
      @expires_at = 0
    end

    def access_token(configuration)
      configuration.validate!
      secret = configuration.client_secret
      key = Digest::SHA256.hexdigest([configuration.tenant_id, configuration.client_id, secret].join("\x00"))
      @mutex.synchronize do
        return @token if @cache_key == key && @token && @clock.call < @expires_at
        @token = nil
        started = @clock.call
        token, lifetime = request_token(configuration, secret)
        # Include network time in expiry; never keep a token beyond its lifetime.
        @expires_at = started + [lifetime - [60, lifetime / 2].min, 0].max
        @cache_key = key
        @token = token
      end
    end

    def invalidate!
      @mutex.synchronize do
        @token = nil
        @expires_at = 0
      end
    end

    def inspect
      '#<Paytech::RedmineMicrosoft365Smtp::TokenProvider [REDACTED]>'
    end

    private

    def request_token(configuration, secret)
      uri = URI("https://login.microsoftonline.com/#{configuration.tenant_id}/oauth2/v2.0/token")
      http = @http_factory.call(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.min_version = OpenSSL::SSL::TLS1_2_VERSION
      http.open_timeout = configuration.open_timeout
      http.read_timeout = configuration.read_timeout
      http.write_timeout = configuration.read_timeout
      request = Net::HTTP::Post.new(uri.request_uri)
      request.set_form_data('client_id' => configuration.client_id, 'client_secret' => secret,
                            'grant_type' => 'client_credentials', 'scope' => SCOPE)
      response = http.request(request)
      raise TokenError, "TOKEN_HTTP_#{response.code.to_i}" unless response.is_a?(Net::HTTPSuccess)
      parsed = JSON.parse(response.body.to_s)
      token = parsed.fetch('access_token')
      lifetime = Integer(parsed.fetch('expires_in'))
      unless token.is_a?(String) && !token.empty? && token.bytesize <= 32768 && !token.match?(/[\s\x00-\x1f\x7f]/) &&
             parsed.fetch('token_type', '').casecmp?('Bearer') && lifetime.positive?
        raise TokenError, 'INVALID_TOKEN_RESPONSE'
      end
      [token, lifetime]
    rescue Error
      raise
    rescue JSON::ParserError, KeyError, ArgumentError, TypeError, NoMethodError
      raise TokenError, 'INVALID_TOKEN_RESPONSE', cause: nil
    rescue StandardError
      raise TokenError, 'TOKEN_CONNECTION_FAILED', cause: nil
    end
  end
end
