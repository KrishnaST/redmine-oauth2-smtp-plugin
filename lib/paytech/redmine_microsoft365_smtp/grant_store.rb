# frozen_string_literal: true

module Paytech::RedmineMicrosoft365Smtp
  # flock serializes token rotation, connect and disconnect across processes.
  class GrantStore
    MAX_BYTES = 131_072

    def self.current
      directory = ENV['REDMINE_M365_STATE_DIRECTORY'].to_s
      raise ConfigurationError, 'STATE_DIRECTORY_REQUIRED' if directory.empty?
      key = Rails.application.key_generator.generate_key('paytech/redmine-m365/grants/v2', 32)
      new(directory: directory, key: key)
    end

    def initialize(directory:, key:)
      @directory = directory
      @key = key
      raise ConfigurationError, 'INVALID_STATE_KEY' unless key.bytesize == 32
    end

    def synchronize
      check_directory!
      File.open(File.join(@directory, 'grant.lock'), File::RDWR | File::CREAT | File::NOFOLLOW, 0o600) do |lock|
        check_file!(lock.stat)
        lock.flock(File::LOCK_EX)
        yield read_document, method(:write_document)
      ensure
        lock&.flock(File::LOCK_UN)
      end
    rescue Error
      raise
    rescue StandardError
      raise ConfigurationError, 'STATE_STORE_FAILED', cause: nil
    end

    def inspect
      '#<Paytech::RedmineMicrosoft365Smtp::GrantStore [REDACTED]>'
    end

    private

    def check_directory!
      stat = File.lstat(@directory)
      unless @directory.start_with?('/') && stat.directory? && !stat.symlink? &&
             stat.uid == Process.euid && (stat.mode & 0o077).zero?
        raise ConfigurationError, 'UNSAFE_STATE_DIRECTORY'
      end
      part = @directory
      until part == '/'
        raise ConfigurationError, 'UNSAFE_STATE_DIRECTORY' if File.lstat(part).symlink?
        part = File.dirname(part)
      end
    end

    def check_file!(stat)
      unless stat.file? && stat.uid == Process.euid && (stat.mode & 0o077).zero? && stat.size <= MAX_BYTES
        raise ConfigurationError, 'UNSAFE_STATE_FILE'
      end
    end

    def read_document
      path = File.join(@directory, 'grant.enc')
      return {} unless File.exist?(path) || File.symlink?(path)
      raw = File.open(path, File::RDONLY | File::NOFOLLOW) do |file|
        check_file!(file.stat)
        file.read(MAX_BYTES + 1)
      end
      envelope = JSON.parse(raw)
      cipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
      cipher.key = @key
      cipher.iv = Base64.strict_decode64(envelope.fetch('iv'))
      cipher.auth_tag = Base64.strict_decode64(envelope.fetch('tag'))
      cipher.auth_data = 'paytech-redmine-m365-v2'
      document = JSON.parse(cipher.update(Base64.strict_decode64(envelope.fetch('data'))) + cipher.final)
      raise ConfigurationError, 'INVALID_STATE_DOCUMENT' unless document.is_a?(Hash)
      document
    end

    def write_document(document)
      cipher = OpenSSL::Cipher.new('aes-256-gcm').encrypt
      cipher.key = @key
      iv = cipher.random_iv
      cipher.auth_data = 'paytech-redmine-m365-v2'
      encrypted = cipher.update(JSON.generate(document)) + cipher.final
      envelope = JSON.generate('iv' => Base64.strict_encode64(iv), 'tag' => Base64.strict_encode64(cipher.auth_tag),
                               'data' => Base64.strict_encode64(encrypted))
      raise ConfigurationError, 'STATE_TOO_LARGE' if envelope.bytesize > MAX_BYTES
      temporary = File.join(@directory, ".grant-#{SecureRandom.hex(16)}")
      File.open(temporary, File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW, 0o600) do |file|
        file.write(envelope)
        file.flush
        file.fsync
      end
      File.rename(temporary, File.join(@directory, 'grant.enc'))
      File.open(@directory) { |directory| directory.fsync }
    ensure
      File.unlink(temporary) if temporary && File.exist?(temporary)
    end
  end
end
