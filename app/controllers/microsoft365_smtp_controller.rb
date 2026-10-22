# frozen_string_literal: true

class Microsoft365SmtpController < ApplicationController
  layout 'admin'
  before_action :require_admin
  before_action :prevent_caching
  require_sudo_mode :create, :connect, :disconnect

  def show; end

  def connection
    @connected = browser_connection.connected?(current_configuration)
  rescue Paytech::RedmineMicrosoft365Smtp::Error => error
    @connected = false
    flash.now[:error] = error.message
  end

  def connect
    destination = browser_connection.start(current_configuration, session: session, user_id: User.current.id)
    redirect_to destination, allow_other_host: true
  rescue Paytech::RedmineMicrosoft365Smtp::Error => error
    connection_error(error)
  end

  def callback
    browser_connection.finish(current_configuration, session: session, user_id: User.current.id,
                              state: params[:state], code: params[:code], denied: params[:error].present?)
    flash[:notice] = 'Microsoft authorized the configured mailbox for SMTP. No email was sent. Enable the plugin only when ready.'
    redirect_to microsoft365_smtp_connection_path
  rescue Paytech::RedmineMicrosoft365Smtp::Error => error
    connection_error(error)
  end

  def disconnect
    browser_connection.disconnect
    session.delete(:m365_oauth_state)
    settings = Setting.plugin_redmine_microsoft365_smtp.to_h.deep_dup
    settings['enabled'] = '0'
    Setting.plugin_redmine_microsoft365_smtp = settings
    flash[:notice] = 'Microsoft connection removed locally and plugin disabled. Revoke consent in Microsoft to revoke the grant there.'
    redirect_to microsoft365_smtp_connection_path
  rescue Paytech::RedmineMicrosoft365Smtp::Error => error
    connection_error(error)
  end

  def create
    recipient = User.current.mail.to_s
    raise Paytech::RedmineMicrosoft365Smtp::ConfigurationError, 'ADMIN_EMAIL_MISSING' if recipient.empty?
    message = Mail.new do
      to recipient
      subject 'Redmine Microsoft 365 SMTP test'
      body 'This test confirms that Microsoft 365 accepted an outbound SMTP submission from Redmine. It does not create a ticket.'
    end
    Paytech::RedmineMicrosoft365Smtp::DeliveryMethod.new.deliver!(message)
    flash[:notice] = 'Microsoft 365 accepted the SMTP submission. Check your own mailbox for delivery.'
    redirect_to microsoft365_smtp_test_path
  rescue Paytech::RedmineMicrosoft365Smtp::Error => error
    flash[:error] = error.message
    redirect_to microsoft365_smtp_test_path
  end

  private

  def current_configuration
    Paytech::RedmineMicrosoft365Smtp::Configuration.current
  end

  def browser_connection
    Paytech::RedmineMicrosoft365Smtp::BrowserConnection.new
  end

  def connection_error(error)
    flash[:error] = error.message
    redirect_to microsoft365_smtp_connection_path
  end

  def prevent_caching
    response.headers['Cache-Control'] = 'no-store'
    response.headers['Referrer-Policy'] = 'no-referrer'
  end
end
