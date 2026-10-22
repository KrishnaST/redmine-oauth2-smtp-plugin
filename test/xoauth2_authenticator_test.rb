# frozen_string_literal: true

require_relative 'test_helper'

class Xoauth2AuthenticatorTest < Minitest::Test
  Response = Struct.new(:successful, :continuation) do
    def success? = successful
    def continue? = continuation
  end

  class AuthSession
    attr_reader :commands

    def initialize(responses)
      @responses = responses
      @commands = []
    end

    def get_response(command)
      @commands << command
      @responses.shift
    end
  end

  def test_registered_handler_sends_microsoft_sasl_format
    assert_equal Paytech::RedmineMicrosoft365Smtp::Xoauth2Authenticator, Net::SMTP::Authenticator.auth_class(:redmine_m365_xoauth2)
    smtp = AuthSession.new([Response.new(true, false)])
    Paytech::RedmineMicrosoft365Smtp::Xoauth2Authenticator.new(smtp).auth('sender@example.invalid', 'test-token')
    assert_equal 'AUTH XOAUTH2', smtp.commands.first.split(' ', 3).first(2).join(' ')
    assert_equal "user=sender@example.invalid\x01auth=Bearer test-token\x01\x01", smtp.commands.first.split.last.unpack1('m0')
  end

  def test_error_challenge_is_terminated_and_error_is_safe
    smtp = AuthSession.new([Response.new(false, true), Response.new(false, false)])
    error = assert_raises(Net::SMTPAuthenticationError) do
      Paytech::RedmineMicrosoft365Smtp::Xoauth2Authenticator.new(smtp).auth('sender@example.invalid', 'test-token')
    end
    assert_equal '', smtp.commands.last
    refute_includes error.message, 'test-token'
  end

  def test_control_character_injection_is_rejected
    smtp = AuthSession.new([])
    assert_raises(ArgumentError) do
      Paytech::RedmineMicrosoft365Smtp::Xoauth2Authenticator.new(smtp).auth("user\x01auth=other", 'test-token')
    end
    assert_empty smtp.commands
  end
end
