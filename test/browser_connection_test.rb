# frozen_string_literal: true

require_relative 'test_helper'

class BrowserConnectionTest < Minitest::Test
  include PluginTestSupport

  def setup
    @now = 1000
    @store = MemoryStore.new
    @session = {}
    @http = FakeHttp.new([success_response])
    @tokens = Paytech::RedmineMicrosoft365Smtp::TokenProvider.new(http_factory: ->(*) { @http })
    @smtp = FakeSmtp.new
    @connection = Paytech::RedmineMicrosoft365Smtp::BrowserConnection.new(
      store: @store, tokens: @tokens, clock: -> { @now }, smtp_factory: -> { @smtp }
    )
  end

  def begin_sign_in
    uri = URI(@connection.start(configuration, session: @session, user_id: 42))
    URI.decode_www_form(uri.query).to_h
  end

  def finish(state: @session[:m365_oauth_state], **arguments)
    @connection.finish(configuration, session: @session, user_id: 42, state: state, code: 'code', **arguments)
  end

  def test_pkce_challenge_callback_scope_and_connected_grant
    query = begin_sign_in
    assert_equal 'S256', query['code_challenge_method']
    verifier = @store.document.dig('pending', 'verifier')
    assert_equal Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false), query['code_challenge']
    refute_includes query.values, verifier
    assert_equal configuration.redirect_uri, query['redirect_uri']
    assert_includes query['scope'], 'offline_access'
    finish
    assert @connection.connected?(configuration)
    assert_nil @session[:m365_oauth_state]
    assert_nil @store.document['pending']
    assert_nil @smtp.sent
    assert_equal 'redmine@example.invalid', @smtp.start_arguments[1]
    assert_equal OpenSSL::SSL::VERIFY_PEER, @smtp.context.verify_mode
    assert_equal verifier, URI.decode_www_form(@http.requests.first.body).to_h['code_verifier']
  end

  def test_state_tampering_replay_expiry_and_cross_user_are_rejected
    begin_sign_in
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { finish(state: 'x' * 43) }
    assert_empty @http.requests
    begin_sign_in
    state = @session[:m365_oauth_state]
    finish
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { finish(state: state) }
    begin_sign_in
    @now += 601
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { finish }
    begin_sign_in
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) do
      @connection.finish(configuration, session: @session, user_id: 99, state: @session[:m365_oauth_state], code: 'code')
    end
  end

  def test_changed_settings_denial_and_disconnect_fence_pending_attempts
    begin_sign_in
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) do
      @connection.finish(configuration({ 'client_id' => '33333333-3333-3333-3333-333333333333' }),
                         session: @session, user_id: 42, state: @session[:m365_oauth_state], code: 'code')
    end
    begin_sign_in
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { finish(denied: true) }
    begin_sign_in
    @connection.disconnect
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { finish }
    assert_empty @http.requests
    refute @connection.connected?(configuration)
  end

  def test_smtp_rejection_does_not_publish_grant_or_leak_response
    begin_sign_in
    @smtp.failure = Net::SMTPAuthenticationError.new('sensitive-provider-details')
    error = assert_raises(Paytech::RedmineMicrosoft365Smtp::DeliveryError) { finish }
    assert_equal 'MAILBOX_AUTHORIZATION_FAILED', error.code
    assert_nil error.cause
    refute @connection.connected?(configuration)
    assert_nil @store.document['pending']
  end
end
