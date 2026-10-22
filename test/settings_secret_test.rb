# frozen_string_literal: true

require_relative 'test_helper'

class SettingsSecretTest < Minitest::Test
  include PluginTestSupport

  def setup
    @key = SecureRandom.random_bytes(32)
    @cipher = Paytech::RedmineMicrosoft365Smtp::SecretCipher.new(key_provider: -> { @key })
    @service = Paytech::RedmineMicrosoft365Smtp::SettingsSecretService.new(cipher: @cipher)
  end

  def test_secret_is_encrypted_and_page_secret_takes_precedence_over_environment
    settings = @service.prepare({}, {}, secret: 'private-test-value')
    encrypted = settings.fetch('client_secret_encrypted')
    refute_includes encrypted, 'private-test-value'
    assert_equal 'private-test-value', @cipher.decrypt(encrypted)
    config = Paytech::RedmineMicrosoft365Smtp::Configuration.new(settings, environment: { 'REDMINE_M365_CLIENT_SECRET' => 'old-value' }, secret_cipher: @cipher)
    assert_equal 'private-test-value', config.client_secret
    refute settings.key?('client_secret')
  end

  def test_blank_retains_and_clear_removes_only_page_secret
    previous = @service.prepare({}, {}, secret: 'test-value')
    assert_equal previous, @service.prepare({}, previous, secret: '')
    cleared = @service.prepare({ 'clear_client_secret' => '1' }, previous)
    refute cleared.key?('client_secret_encrypted')
    refute cleared.key?('clear_client_secret')
    config = Paytech::RedmineMicrosoft365Smtp::Configuration.new(cleared, environment: { 'REDMINE_M365_CLIENT_SECRET' => 'server-secret' })
    assert_equal 'server-secret', config.client_secret
  end

  def test_client_supplied_ciphertext_is_ignored
    assert_empty @service.prepare({ 'client_secret_encrypted' => 'injected', 'client_secret' => 'plaintext' }, {})
  end

  def test_clear_replace_conflict_and_invalid_inputs_are_rejected_safely
    error = assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) do
      @service.prepare({ 'clear_client_secret' => '1' }, {}, secret: 'private')
    end
    refute_includes error.message, 'private'
    [[], "private\nvalue", 'x' * 4097].each do |secret|
      assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { @service.prepare({}, {}, secret: secret) }
    end
  end

  def test_tampering_wrong_key_and_corrupt_ciphertext_never_fall_back
    encrypted = @cipher.encrypt('private')
    @key = SecureRandom.random_bytes(32)
    config = Paytech::RedmineMicrosoft365Smtp::Configuration.new({ 'client_secret_encrypted' => encrypted },
                                                              environment: { 'REDMINE_M365_CLIENT_SECRET' => 'fallback' }, secret_cipher: @cipher)
    error = assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { config.client_secret }
    assert_equal 'SECRET_DECRYPTION_FAILED', error.code
    assert_nil error.cause
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { @cipher.decrypt('{bad') }
  end
end
