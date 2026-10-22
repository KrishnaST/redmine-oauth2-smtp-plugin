# frozen_string_literal: true

require_relative 'test_helper'

class DeliveryMethodTest < Minitest::Test
  include PluginTestSupport

  def build_message
    Mail.new do
      from 'original@example.invalid'
      to 'recipient@example.invalid'
      cc 'copy@example.invalid'
      bcc 'hidden@example.invalid'
      reply_to 'reply@example.invalid'
      subject 'Unit test'
      body 'No real email is sent.'
      add_file filename: 'test.txt', content: 'attachment'
    end
  end

  def delivery(smtp, tokens = FakeTokens.new, config = configuration)
    Paytech::RedmineMicrosoft365Smtp::DeliveryMethod.new(configuration_provider: -> { config },
                                                token_provider: tokens, smtp_factory: -> { smtp })
  end

  def test_native_mail_envelope_preserves_recipients_bcc_and_attachments
    smtp = FakeSmtp.new
    mail = build_message
    delivery(smtp).deliver!(mail)
    assert_equal ['redmine.example.invalid', 'redmine@example.invalid', 'test-access-token', :redmine_m365_xoauth2], smtp.start_arguments
    assert_equal OpenSSL::SSL::VERIFY_PEER, smtp.context.verify_mode
    assert_equal ['redmine@example.invalid'], mail.from
    assert_equal ['reply@example.invalid'], mail.reply_to
    assert_equal 'redmine@example.invalid', smtp.sent[1]
    assert_equal ['recipient@example.invalid', 'copy@example.invalid', 'hidden@example.invalid'].sort, smtp.sent[2].sort
    refute_match(/^Bcc:/i, smtp.sent[0])
    assert_includes smtp.sent[0], 'test.txt'
    assert_equal 15, smtp.open_timeout
    assert_equal 30, smtp.read_timeout
  end

  def test_disabled_or_invalid_configuration_fails_closed
    smtp = FakeSmtp.new
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { delivery(smtp, FakeTokens.new, configuration({ 'enabled' => '0' })).deliver!(build_message) }
    assert_nil smtp.start_arguments
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { delivery(smtp, FakeTokens.new, configuration({ 'tenant_id' => 'invalid' })).deliver!(build_message) }
    assert_nil smtp.sent
  end

  def test_authentication_failure_invalidates_cache_and_never_sends
    smtp = FakeSmtp.new
    smtp.failure = Net::SMTPAuthenticationError.new('sensitive-provider-error')
    tokens = FakeTokens.new
    error = assert_raises(Paytech::RedmineMicrosoft365Smtp::DeliveryError) { delivery(smtp, tokens).deliver!(build_message) }
    assert_equal 'SMTP_AUTH_REJECTED', error.code
    assert_equal 1, tokens.invalidations
    assert_nil smtp.sent
    assert_nil error.cause
    refute_includes error.message, 'sensitive-provider-error'
  end

  def test_tls_and_generic_failures_are_safe_and_not_retried
    [OpenSSL::SSL::SSLError.new('private-tls-detail'), IOError.new('private-data')].each do |failure|
      smtp = FakeSmtp.new
      smtp.failure = failure
      error = assert_raises(Paytech::RedmineMicrosoft365Smtp::DeliveryError) { delivery(smtp).deliver!(build_message) }
      refute_includes error.message, 'private'
      assert_nil error.cause
      assert_nil smtp.sent
    end
  end
end
