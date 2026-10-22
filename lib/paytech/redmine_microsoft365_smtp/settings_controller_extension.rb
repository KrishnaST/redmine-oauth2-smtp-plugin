# frozen_string_literal: true

module Paytech::RedmineMicrosoft365Smtp
  # Runs as the action, after native SettingsController admin/sudo/CSRF callbacks.
  module SettingsControllerExtension
    def plugin
      if request.post? && params[:id].to_s == 'redmine_microsoft365_smtp'
        submitted = params[:settings] || ActionController::Parameters.new
        secret = submitted.delete(:client_secret)
        safe = m365_settings_secret_service.prepare(submitted.to_unsafe_h,
                                                 Setting.plugin_redmine_microsoft365_smtp, secret: secret)
        params[:settings] = ActionController::Parameters.new(safe)
      end
      super
    rescue Paytech::RedmineMicrosoft365Smtp::Error => error
      flash[:error] = error.message
      redirect_to plugin_settings_path('redmine_microsoft365_smtp')
    end

    private

    def m365_settings_secret_service
      SettingsSecretService.new
    end
  end
end
