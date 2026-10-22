# frozen_string_literal: true

require_relative 'controller_test'

class Setting
  def self.plugin_redmine_microsoft365_smtp
    Thread.current[:m365_previous_settings] || {}
  end
end

class SettingsController < ApplicationController
  before_action :require_admin
  require_sudo_mode :plugin
  prepend Paytech::RedmineMicrosoft365Smtp::SettingsControllerExtension

  def plugin
    Thread.current[:m365_persisted_settings] = params[:settings].to_unsafe_h
    head :ok
  end
end

class SettingsControllerTest < ActionController::TestCase
  tests SettingsController

  def setup
    super
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw { post 'settings/plugin/:id', to: 'settings#plugin', as: :plugin_settings }
    SettingsController.include(@routes.url_helpers)
    SettingsController.allow_forgery_protection = false
    Thread.current[:plugin_test_user] = User::Account.new('admin@example.invalid', true, true)
    Thread.current[:m365_persisted_settings] = nil
    Thread.current[:m365_previous_settings] = {}
    key = SecureRandom.random_bytes(32)
    @cipher = Paytech::RedmineMicrosoft365Smtp::SecretCipher.new(key_provider: -> { key })
    service = Paytech::RedmineMicrosoft365Smtp::SettingsSecretService.new(cipher: @cipher)
    @controller.define_singleton_method(:m365_settings_secret_service) { service }
  end

  def teardown
    [:plugin_test_user, :m365_persisted_settings, :m365_previous_settings].each { |key| Thread.current[key] = nil }
    super
  end

  def save_secret(value)
    post :plugin, params: { id: 'redmine_microsoft365_smtp', settings: { client_secret: value, tenant_id: 'retained-id' } }
  end

  def test_native_action_receives_only_encrypted_secret_and_blank_preserves_it
    save_secret('private-value')
    assert_response :ok
    saved = Thread.current[:m365_persisted_settings]
    refute saved.key?('client_secret')
    assert_equal 'private-value', @cipher.decrypt(saved.fetch('client_secret_encrypted'))
    Thread.current[:m365_previous_settings] = saved
    save_secret('')
    assert_equal saved['client_secret_encrypted'], Thread.current[:m365_persisted_settings]['client_secret_encrypted']
  end

  def test_admin_sudo_and_csrf_boundaries_prevent_saving
    Thread.current[:plugin_test_user].admin = false
    save_secret('private')
    assert_response :forbidden
    assert_nil Thread.current[:m365_persisted_settings]
    Thread.current[:plugin_test_user].admin = true
    Thread.current[:plugin_test_user].sudo = false
    save_secret('private')
    assert_response :forbidden
    Thread.current[:plugin_test_user].sudo = true
    SettingsController.allow_forgery_protection = true
    assert_raises(ActionController::InvalidAuthenticityToken) { save_secret('private') }
    assert_nil Thread.current[:m365_persisted_settings]
  ensure
    SettingsController.allow_forgery_protection = false
  end

  def test_invalid_secret_never_reaches_native_save_or_flash
    save_secret("private\nvalue")
    assert_response :redirect
    assert_nil Thread.current[:m365_persisted_settings]
    refute_includes flash[:error], 'private'
    refute @controller.params[:settings].key?('client_secret')
  end

  def test_other_plugins_are_not_intercepted
    post :plugin, params: { id: 'other_plugin', settings: { client_secret: 'other-plugin-value' } }
    assert_equal 'other-plugin-value', Thread.current[:m365_persisted_settings]['client_secret']
  end
end
