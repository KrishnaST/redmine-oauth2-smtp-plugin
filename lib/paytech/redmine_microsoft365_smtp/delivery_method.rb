# frozen_string_literal: true

module Paytech::RedmineMicrosoft365Smtp
  class DeliveryMethod
    attr_accessor :settings

    def initialize(settings = {}, configuration_provider: -> { Configuration.current },
                   token_provider: TokenProvider.instance,
                   smtp_factory: -> { Net::SMTP.new('smtp.office365.com', 587) })
      @settings = settings
      @configuration_provider = configuration_provider
      @token_provider = token_provider
      @smtp_factory = smtp_factory
    end

    def deliver!(message)
      configuration = @configuration_provider.call.validate!
      raise ConfigurationError, 'PLUGIN_DISABLED' unless configuration.enabled?
      token = @token_provider.access_token(configuration)
      address = Mail::Address.new(configuration.mailbox)
      address.display_name = configuration.sender_name unless configuration.sender_name.empty?
      message.from = address.format
      message.sender = nil
      message.return_path = nil
      message.smtp_envelope_from = configuration.mailbox
      smtp = @smtp_factory.call
      context = OpenSSL::SSL::SSLContext.new
      context.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
      context.min_version = OpenSSL::SSL::TLS1_2_VERSION
      smtp.enable_starttls(context)
      smtp.open_timeout = configuration.open_timeout
      smtp.read_timeout = configuration.read_timeout
      smtp.start(configuration.helo_domain, configuration.mailbox, token, :redmine_m365_xoauth2) do |connection|
        Mail::SMTPConnection.new(connection: connection).deliver!(message)
      end
      self
    rescue Net::SMTPAuthenticationError
      @token_provider.invalidate!
      raise DeliveryError, 'SMTP_AUTH_REJECTED', cause: nil
    rescue Error
      raise
    rescue OpenSSL::SSL::SSLError
      raise DeliveryError, 'SMTP_TLS_FAILED', cause: nil
    rescue Net::SMTPServerBusy
      raise DeliveryError, 'SMTP_TEMPORARY_FAILURE', cause: nil
    rescue StandardError
      # Never propagate SMTP responses, addresses, MIME bodies or tokens to logs.
      # In particular do not retry after DATA: delivery may already have succeeded.
      raise DeliveryError, 'SMTP_DELIVERY_FAILED', cause: nil
    end

    def inspect
      '#<Paytech::RedmineMicrosoft365Smtp::DeliveryMethod [REDACTED]>'
    end
  end
end
