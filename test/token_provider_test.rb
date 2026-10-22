# frozen_string_literal: true

require_relative 'test_helper'

class TokenProviderTest < Minitest::Test
  include PluginTestSupport

  def test_uses_application_permission_and_verified_https
    http = FakeHttp.new([success_response])
    endpoints = []
    provider = Paytech::RedmineMicrosoft365Smtp::TokenProvider.new(http_factory: ->(host, port) { endpoints << [host, port]; http })
    assert_equal 'test-access-token', provider.access_token(configuration)
    assert_equal [['login.microsoftonline.com', 443]], endpoints
    assert http.use_ssl
    assert_equal OpenSSL::SSL::VERIFY_PEER, http.verify_mode
    assert_equal OpenSSL::SSL::TLS1_2_VERSION, http.min_version
    form = URI.decode_www_form(http.requests.first.body).to_h
    assert_equal 'client_credentials', form['grant_type']
    assert_equal 'https://outlook.office365.com/.default', form['scope']
    assert_equal 'unit-test-secret', form['client_secret']
    assert_includes http.requests.first.path, '11111111-1111-1111-1111-111111111111/oauth2/v2.0/token'
    refute_includes provider.inspect, 'test-access-token'
  end

  def test_caches_and_renews_before_expiry
    now = 0
    http = FakeHttp.new([success_response(token: 'first'), success_response(token: 'second')])
    provider = Paytech::RedmineMicrosoft365Smtp::TokenProvider.new(http_factory: ->(*) { http }, clock: -> { now })
    assert_equal 'first', provider.access_token(configuration)
    now = 3539
    assert_equal 'first', provider.access_token(configuration)
    now = 3540
    assert_equal 'second', provider.access_token(configuration)
    assert_equal 2, http.requests.length
  end

  def test_rotation_or_explicit_invalidation_refreshes_token
    http = FakeHttp.new([success_response])
    provider = Paytech::RedmineMicrosoft365Smtp::TokenProvider.new(http_factory: ->(*) { http })
    provider.access_token(configuration)
    provider.access_token(configuration(environment: { 'REDMINE_M365_CLIENT_SECRET' => 'rotated-test-secret' }))
    provider.invalidate!
    provider.access_token(configuration)
    assert_equal 3, http.requests.length
  end

  def test_parallel_requests_share_one_cached_token
    http = FakeHttp.new([success_response])
    provider = Paytech::RedmineMicrosoft365Smtp::TokenProvider.new(http_factory: ->(*) { http })
    threads = 12.times.map { Thread.new { provider.access_token(configuration) } }
    assert_equal ['test-access-token'], threads.map(&:value).uniq
    assert_equal 1, http.requests.length
  end

  def test_http_failures_do_not_expose_provider_body
    [Net::HTTPUnauthorized, Net::HTTPFound, Net::HTTPTooManyRequests].each do |type|
      response = type.new('1.1', type == Net::HTTPFound ? '302' : '401', 'Rejected')
      response.define_singleton_method(:body) { 'secret-and-provider-sensitive-error' }
      provider = Paytech::RedmineMicrosoft365Smtp::TokenProvider.new(http_factory: ->(*) { FakeHttp.new([response]) })
      error = assert_raises(Paytech::RedmineMicrosoft365Smtp::TokenError) { provider.access_token(configuration) }
      refute_includes error.message, 'secret-and-provider-sensitive-error'
      assert_nil error.cause
    end
  end

  def test_malformed_token_response_and_network_failure_are_sanitized
    response = success_response
    response.define_singleton_method(:body) { '{secret-invalid-json' }
    provider = Paytech::RedmineMicrosoft365Smtp::TokenProvider.new(http_factory: ->(*) { FakeHttp.new([response]) })
    error = assert_raises(Paytech::RedmineMicrosoft365Smtp::TokenError) { provider.access_token(configuration) }
    assert_equal 'INVALID_TOKEN_RESPONSE', error.code
    assert_nil error.cause
    provider = Paytech::RedmineMicrosoft365Smtp::TokenProvider.new(http_factory: ->(*) { raise IOError, 'secret' })
    error = assert_raises(Paytech::RedmineMicrosoft365Smtp::TokenError) { provider.access_token(configuration) }
    assert_equal 'TOKEN_CONNECTION_FAILED', error.code
    refute_includes error.message, 'secret'
  end

  def test_short_lived_tokens_are_not_cached_past_expiry
    now = 0
    http = FakeHttp.new([success_response(lifetime: 10)])
    provider = Paytech::RedmineMicrosoft365Smtp::TokenProvider.new(http_factory: ->(*) { http }, clock: -> { now })
    provider.access_token(configuration)
    now = 6
    provider.access_token(configuration)
    assert_equal 2, http.requests.length
  end
end
