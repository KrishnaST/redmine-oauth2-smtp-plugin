# frozen_string_literal: true

module Paytech::RedmineMicrosoft365Smtp
  class Configuration
    DEFAULTS = {
      'enabled' => '0', 'tenant_id' => '', 'client_id' => '', 'mailbox' => '',
      'sender_name' => 'Redmine', 'helo_domain' => 'localhost',
      'open_timeout' => '15', 'read_timeout' => '30'
    }.freeze
    UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    MAILBOX = /\A[A-Za-z0-9.!#$%&'*+\/=\?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\z/

    attr_reader :tenant_id, :client_id, :mailbox, :sender_name, :helo_domain,
                :open_timeout, :read_timeout

    def self.current
      new(Setting.plugin_redmine_microsoft365_smtp)
    end

    def initialize(settings, environment: ENV)
      @settings = DEFAULTS.merge(settings.to_h.transform_keys(&:to_s))
      @environment = environment
      @tenant_id = @settings['tenant_id'].to_s.strip
      @client_id = @settings['client_id'].to_s.strip
      @mailbox = @settings['mailbox'].to_s.strip
      @sender_name = @settings['sender_name'].to_s.strip
      @helo_domain = @settings['helo_domain'].to_s.strip
    end

    def enabled?
      @settings['enabled'].to_s == '1'
    end

    def validate!
      raise ConfigurationError, 'INVALID_TENANT_ID' unless UUID.match?(tenant_id)
      raise ConfigurationError, 'INVALID_CLIENT_ID' unless UUID.match?(client_id)
      raise ConfigurationError, 'INVALID_MAILBOX' unless MAILBOX.match?(mailbox) && mailbox.bytesize <= 254
      raise ConfigurationError, 'INVALID_SENDER_NAME' if sender_name.bytesize > 128 || sender_name.match?(/[\r\n\x00]/)
      raise ConfigurationError, 'INVALID_HELO_DOMAIN' unless /\A[A-Za-z0-9][A-Za-z0-9.-]{0,252}\z/.match?(helo_domain)
      @open_timeout = bounded_timeout(@settings['open_timeout'])
      @read_timeout = bounded_timeout(@settings['read_timeout'])
      self
    end

    def client_secret
      path = @environment['REDMINE_M365_CLIENT_SECRET_FILE'].to_s
      value = if path.empty?
                @environment['REDMINE_M365_CLIENT_SECRET'].to_s
              else
                read_secret_file(path)
              end
      value = value.strip
      raise ConfigurationError, 'MISSING_CLIENT_SECRET' if value.empty?
      raise ConfigurationError, 'INVALID_CLIENT_SECRET' if value.bytesize > 4096 || value.match?(/[\r\n\x00]/)
      value
    end

    # Avoid exposing identifiers or credentials in framework exception inspection.
    def inspect
      '#<Paytech::RedmineMicrosoft365Smtp::Configuration [REDACTED]>'
    end

    private

    def bounded_timeout(value)
      number = Integer(value, 10)
      raise ConfigurationError, 'INVALID_TIMEOUT' unless (1..120).cover?(number)
      number
    rescue ArgumentError, TypeError
      raise ConfigurationError, 'INVALID_TIMEOUT', cause: nil
    end

    def read_secret_file(path)
      stat = File.lstat(path)
      unless stat.file? && (stat.mode & 0o077).zero? && [0, Process.euid].include?(stat.uid) && stat.size <= 4096
        raise ConfigurationError, 'UNSAFE_SECRET_FILE'
      end
      File.read(path, 4097)
    rescue SystemCallError, IOError
      raise ConfigurationError, 'SECRET_FILE_UNREADABLE', cause: nil
    end
  end
end
