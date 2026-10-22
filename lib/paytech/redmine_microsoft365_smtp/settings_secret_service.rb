# frozen_string_literal: true

module Paytech::RedmineMicrosoft365Smtp
  class SettingsSecretService
    def initialize(cipher: SecretCipher.new)
      @cipher = cipher
    end

    def prepare(settings, previous, secret: nil)
      result = settings.to_h.transform_keys(&:to_s)
      result.delete('client_secret')
      result.delete('client_secret_encrypted') # Never accept client-supplied ciphertext.
      clear = result.delete('clear_client_secret').to_s == '1'
      unless secret.nil? || secret.is_a?(String)
        raise ConfigurationError, 'INVALID_CLIENT_SECRET'
      end
      value = secret.to_s.strip
      if clear && !value.empty?
        raise ConfigurationError, 'SECRET_CLEAR_AND_REPLACE_CONFLICT'
      end
      if value.bytesize > 4096 || value.match?(/[\r\n\x00]/)
        raise ConfigurationError, 'INVALID_CLIENT_SECRET'
      end
      encrypted = previous.to_h['client_secret_encrypted'].to_s
      encrypted = '' if clear
      encrypted = @cipher.encrypt(value) unless value.empty?
      result['client_secret_encrypted'] = encrypted unless encrypted.empty?
      result
    end
  end
end
