# frozen_string_literal: true

# Run from the installed Redmine root with its bundle and explicit PGOPTIONS
# read-only policy. Discovery changes only in this isolated process; no deploy.
require 'tmpdir'

root = ENV.fetch('M365_PLUGIN_VALIDATION_ROOT')
raise 'Read-only database policy required' unless ENV['PGOPTIONS'].to_s.include?('default_transaction_read_only=on')
require File.expand_path('config/application', Dir.pwd)
Rails.application.config.redmine_plugins_directory = File.dirname(root)
require File.expand_path('config/environment', Dir.pwd)

ActiveRecord::Base.transaction do
  ActiveRecord::Base.connection.execute('SET TRANSACTION READ ONLY')
  raise 'Wrong plugin version' unless Redmine::Plugin.find(:redmine_microsoft365_smtp).version == '2.0.1'
  load File.join(root, 'app/controllers/microsoft365_smtp_controller.rb')
  unless ActionMailer::Base.delivery_methods[:redmine_microsoft365_smtp] == Paytech::RedmineMicrosoft365Smtp::DeliveryMethod
    raise 'Delivery method missing'
  end
  route = Rails.application.routes.recognize_path('/admin/microsoft365_smtp/callback', method: :get)
  raise 'Callback missing' unless route[:action] == 'callback'
  filter = ActiveSupport::ParameterFilter.new(Rails.application.env_config.fetch('action_dispatch.parameter_filter'))
  raise 'OAuth logging filter missing' unless filter.filter('code' => 'test-only')['code'] == '[FILTERED]'
  rendered = Microsoft365SmtpController.render(template: 'microsoft365_smtp/connection', layout: false,
                                              assigns: { connected: false })
  raise 'Connection view missing' unless rendered.include?('Connect / reconnect Microsoft account')
  settings_view = Microsoft365SmtpController.render(partial: 'settings/microsoft365_smtp',
                                                    assigns: { settings: Paytech::RedmineMicrosoft365Smtp::Configuration::DEFAULTS })
  unless settings_view.include?('data-method="post"') && settings_view.include?('>Connect Microsoft</a>') && !settings_view.include?('<form')
    raise 'Direct connect link must use native Redmine UJS POST without nested forms'
  end
  Dir.mktmpdir('native-state-', File.dirname(root)) do |directory|
    ENV['REDMINE_M365_STATE_DIRECTORY'] = directory
    store = Paytech::RedmineMicrosoft365Smtp::GrantStore.current
    store.synchronize { |_document, save| save.call('test_only' => true) }
    store.synchronize { |document, _save| raise 'Encrypted store failed' unless document['test_only'] }
  end
  puts "NATIVE_PKCE_BOOT_OK enabled=#{Paytech::RedmineMicrosoft365Smtp::Configuration.current.enabled?}"
end
