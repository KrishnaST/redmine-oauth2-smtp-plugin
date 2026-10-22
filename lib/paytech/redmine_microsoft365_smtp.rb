# frozen_string_literal: true

require 'base64'
require 'digest'
require 'json'
require 'mail'
require 'net/http'
require 'net/smtp'
require 'openssl'
require 'securerandom'
require 'thread'
require 'uri'

require_relative '../paytech'

module Paytech::RedmineMicrosoft365Smtp
  class Error < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super("Microsoft 365 SMTP: #{code}. See plugin troubleshooting documentation.")
    end
  end

  class ConfigurationError < Error; end
  class TokenError < Error; end
  class DeliveryError < Error; end
end

require_relative 'redmine_microsoft365_smtp/secret_cipher'
require_relative 'redmine_microsoft365_smtp/settings_secret_service'
require_relative 'redmine_microsoft365_smtp/settings_controller_extension'
require_relative 'redmine_microsoft365_smtp/configuration'
require_relative 'redmine_microsoft365_smtp/grant_store'
require_relative 'redmine_microsoft365_smtp/token_provider'
require_relative 'redmine_microsoft365_smtp/xoauth2_authenticator'
require_relative 'redmine_microsoft365_smtp/browser_connection'
require_relative 'redmine_microsoft365_smtp/delivery_method'
require_relative 'redmine_microsoft365_smtp/interceptor'
