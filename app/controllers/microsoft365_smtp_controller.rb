# frozen_string_literal: true

class Microsoft365SmtpController < ApplicationController
  layout 'admin'
  before_action :require_admin
  require_sudo_mode :create

  def show; end

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
end
