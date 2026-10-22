# frozen_string_literal: true

module Paytech::RedmineMicrosoft365Smtp
  class SecretCipher
    def initialize(key_provider: -> { Rails.application.key_generator.generate_key('paytech/redmine-m365/client-secret/v1', 32) })
      @key_provider = key_provider
    end

    def encrypt(value)
      cipher = OpenSSL::Cipher.new('aes-256-gcm').encrypt
      cipher.key = @key_provider.call
      iv = cipher.random_iv
      cipher.auth_data = 'paytech-redmine-m365-client-secret'
      data = cipher.update(value) + cipher.final
      JSON.generate('iv' => Base64.strict_encode64(iv), 'tag' => Base64.strict_encode64(cipher.auth_tag), 'data' => Base64.strict_encode64(data))
    rescue StandardError
      raise ConfigurationError, 'SECRET_ENCRYPTION_FAILED', cause: nil
    end

    def decrypt(value)
      raise ArgumentError if value.bytesize > 16_384
      envelope = JSON.parse(value)
      cipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
      cipher.key = @key_provider.call
      cipher.iv = Base64.strict_decode64(envelope.fetch('iv'))
      cipher.auth_tag = Base64.strict_decode64(envelope.fetch('tag'))
      cipher.auth_data = 'paytech-redmine-m365-client-secret'
      cipher.update(Base64.strict_decode64(envelope.fetch('data'))) + cipher.final
    rescue StandardError
      raise ConfigurationError, 'SECRET_DECRYPTION_FAILED', cause: nil
    end
  end
end
