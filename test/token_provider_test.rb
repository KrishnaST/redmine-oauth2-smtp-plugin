# frozen_string_literal: true

require_relative 'test_helper'

class TokenProviderTest < Minitest::Test
  include PluginTestSupport

  def setup
    @now = 1000
    @store = MemoryStore.new('grant' => { 'identity' => configuration.connection_identity,
                                         'refresh_token' => 'old-refresh', 'expires_at' => 0 })
    @http = FakeHttp.new([success_response])
    @provider = Paytech::RedmineMicrosoft365Smtp::TokenProvider.new(
      http_factory: ->(host, port) { assert_equal ['login.microsoftonline.com', 443], [host, port]; @http },
      store_provider: -> { @store }, clock: -> { @now }
    )
  end

  def test_refreshes_delegated_grant_over_verified_https_and_persists_rotation
    assert_equal 'test-access-token', @provider.access_token(configuration)
    form = URI.decode_www_form(@http.requests.first.body).to_h
    assert_equal 'refresh_token', form['grant_type']
    assert_equal 'old-refresh', form['refresh_token']
    assert_includes form['scope'], 'https://outlook.office.com/SMTP.Send'
    refute_includes form['scope'], '.default'
    assert_equal 'unit-test-secret', form['client_secret']
    assert_equal 'test-refresh-token', @store.document.dig('grant', 'refresh_token')
    assert @http.use_ssl
    assert_equal OpenSSL::SSL::VERIFY_PEER, @http.verify_mode
    assert_equal OpenSSL::SSL::TLS1_2_VERSION, @http.min_version
    refute_includes @provider.inspect, 'test-access-token'
  end

  def test_caches_until_expiry_and_invalidates
    @provider.access_token(configuration)
    @now = 4539
    @provider.access_token(configuration)
    assert_equal 1, @http.requests.length
    @now = 4540
    @provider.access_token(configuration)
    assert_equal 2, @http.requests.length
    @provider.invalidate!
    @provider.access_token(configuration)
    assert_equal 3, @http.requests.length
  end

  def test_parallel_requests_share_one_rotation
    threads = 12.times.map { Thread.new { @provider.access_token(configuration) } }
    assert_equal ['test-access-token'], threads.map(&:value).uniq
    assert_equal 1, @http.requests.length
  end

  def test_code_exchange_sends_pkce_and_exact_callback
    @provider.exchange_code(configuration, code: 'authorization-code', verifier: 'pkce-verifier')
    form = URI.decode_www_form(@http.requests.first.body).to_h
    assert_equal 'authorization_code', form['grant_type']
    assert_equal 'authorization-code', form['code']
    assert_equal 'pkce-verifier', form['code_verifier']
    assert_equal configuration.redirect_uri, form['redirect_uri']
  end

  def test_changed_settings_or_missing_grant_require_reconnect
    error = assert_raises(Paytech::RedmineMicrosoft365Smtp::TokenError) do
      @provider.access_token(configuration({ 'mailbox' => 'other@example.invalid' }))
    end
    assert_equal 'MICROSOFT_RECONNECT_REQUIRED', error.code
    assert_empty @http.requests
  end

  def test_invalid_grant_and_provider_errors_are_sanitized
    [Net::HTTPBadRequest, Net::HTTPUnauthorized, Net::HTTPFound].each do |type|
      response = type.new('1.1', type == Net::HTTPBadRequest ? '400' : '401', 'Rejected')
      response.define_singleton_method(:body) { 'sensitive-provider-message' }
      @http = FakeHttp.new([response])
      error = assert_raises(Paytech::RedmineMicrosoft365Smtp::TokenError) { @provider.access_token(configuration) }
      refute_includes error.message, 'sensitive-provider-message'
      assert_equal 'old-refresh', @store.document.dig('grant', 'refresh_token')
    end
  end

  def test_malformed_response_wrong_scope_and_network_failure
    ['{broken', JSON.generate('token_type' => 'Bearer', 'expires_in' => 3600, 'access_token' => 'token', 'scope' => 'User.Read')].each do |body|
      response = success_response
      response.define_singleton_method(:body) { body }
      @http = FakeHttp.new([response])
      error = assert_raises(Paytech::RedmineMicrosoft365Smtp::TokenError) { @provider.access_token(configuration) }
      assert_equal 'INVALID_TOKEN_RESPONSE', error.code
    end
    provider = Paytech::RedmineMicrosoft365Smtp::TokenProvider.new(http_factory: ->(*) { raise IOError, 'sensitive' }, store_provider: -> { @store })
    error = assert_raises(Paytech::RedmineMicrosoft365Smtp::TokenError) { provider.access_token(configuration) }
    assert_equal 'TOKEN_CONNECTION_FAILED', error.code
    assert_nil error.cause
  end

  def test_refresh_response_without_new_refresh_token_retains_previous
    @http = FakeHttp.new([success_response(refresh: nil)])
    @provider.access_token(configuration)
    assert_equal 'old-refresh', @store.document.dig('grant', 'refresh_token')
    error = assert_raises(Paytech::RedmineMicrosoft365Smtp::TokenError) do
      @provider.exchange_code(configuration, code: 'code', verifier: 'verifier')
    end
    assert_equal 'REFRESH_TOKEN_REQUIRED', error.code
  end

  def test_oversized_response_and_save_failure_fail_before_token_is_returned
    response = success_response
    response.define_singleton_method(:body) { 'x' * 65_537 }
    @http = FakeHttp.new([response])
    error = assert_raises(Paytech::RedmineMicrosoft365Smtp::TokenError) { @provider.access_token(configuration) }
    assert_equal 'INVALID_TOKEN_RESPONSE', error.code
    assert_equal 'old-refresh', @store.document.dig('grant', 'refresh_token')
    @http = FakeHttp.new([success_response])
    failing_store = Object.new
    document = @store.document
    failing_store.define_singleton_method(:synchronize) do |&block|
      block.call(document, ->(_value) { raise Paytech::RedmineMicrosoft365Smtp::ConfigurationError, 'STATE_STORE_FAILED' })
    end
    provider = Paytech::RedmineMicrosoft365Smtp::TokenProvider.new(http_factory: ->(*) { @http }, store_provider: -> { failing_store })
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { provider.access_token(configuration) }
  end
end
