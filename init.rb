# frozen_string_literal: true

require_relative 'lib/paytech/redmine_microsoft365_smtp'

Redmine::Plugin.register :redmine_microsoft365_smtp do
  name 'Microsoft 365 SMTP OAuth2'
  author 'Paytech'
  description 'Outbound Redmine notifications through Microsoft 365 SMTP XOAUTH2.'
  version '2.0.3'
  requires_redmine version_or_higher: '7.0.0'
  settings default: Paytech::RedmineMicrosoft365Smtp::Configuration::DEFAULTS,
           partial: 'settings/microsoft365_smtp'
end

# Redmine's PluginLoader already invokes init.rb in its own to_prepare callback.
# Register immediately: nesting config.to_prepare here can miss initial boot.
ActionMailer::Base.add_delivery_method(
  :redmine_microsoft365_smtp, Paytech::RedmineMicrosoft365Smtp::DeliveryMethod
)
ActionMailer::Base.register_interceptor(Paytech::RedmineMicrosoft365Smtp::Interceptor)

# Query-mode callback keeps SameSite=Lax Redmine sessions on the HTTPS return.
# Proxies/access logs must also suppress its query string; see deployment guide.
if defined?(Rails) && Rails.application
  unless SettingsController < Paytech::RedmineMicrosoft365Smtp::SettingsControllerExtension
    SettingsController.prepend(Paytech::RedmineMicrosoft365Smtp::SettingsControllerExtension)
  end
  sensitive_parameters = [:code, :state, :error_description, :client_secret, :refresh_token, :access_token]
  Rails.application.config.filter_parameters |= sensitive_parameters
  Rails.application.env_config['action_dispatch.parameter_filter'] = Rails.application.config.filter_parameters
end
