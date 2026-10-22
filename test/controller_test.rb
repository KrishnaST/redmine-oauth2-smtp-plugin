# frozen_string_literal: true

require 'action_controller'
require 'action_controller/test_case'
require_relative 'test_helper'

# Isolated Redmine controller contract: exercise the real plugin controller with
# stand-ins for Redmine's existing authentication hooks, without a live database.
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  def self.require_sudo_mode(*actions)
    before_action :verify_test_sudo_mode, only: actions
  end

  private

  def require_admin
    head :forbidden unless User.current&.admin
  end

  def verify_test_sudo_mode
    head :forbidden unless User.current&.sudo
  end
end

class User
  Account = Struct.new(:mail, :admin, :sudo) do
    def id
      42
    end
  end

  def self.current
    Thread.current[:plugin_test_user]
  end
end

require_relative '../app/controllers/microsoft365_smtp_controller'

class ControllerTest < ActionController::TestCase
  include PluginTestSupport
  tests Microsoft365SmtpController

  def setup
    super
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get 'admin/microsoft365_smtp/test', to: 'microsoft365_smtp#show', as: :microsoft365_smtp_test
      post 'admin/microsoft365_smtp/test', to: 'microsoft365_smtp#create'
      get 'admin/microsoft365_smtp/connection', to: 'microsoft365_smtp#connection', as: :microsoft365_smtp_connection
      post 'admin/microsoft365_smtp/connect', to: 'microsoft365_smtp#connect', as: :microsoft365_smtp_connect
      get 'admin/microsoft365_smtp/callback', to: 'microsoft365_smtp#callback', as: :microsoft365_smtp_callback
      post 'admin/microsoft365_smtp/disconnect', to: 'microsoft365_smtp#disconnect', as: :microsoft365_smtp_disconnect
      get 'settings/plugin/:id', to: 'settings#plugin', as: :plugin_settings
    end
    Microsoft365SmtpController.include(@routes.url_helpers)
    Microsoft365SmtpController.allow_forgery_protection = false
    Thread.current[:plugin_test_user] = User::Account.new('admin@example.invalid', true, true)
  end

  def teardown
    Thread.current[:plugin_test_user] = nil
    super
  end

  def test_get_requires_administrator
    Thread.current[:plugin_test_user] = User::Account.new('member@example.invalid', false, false)
    get :show
    assert_response :forbidden
  end

  def test_post_requires_administrator
    Thread.current[:plugin_test_user] = nil
    post :create
    assert_response :forbidden
  end

  def test_connect_and_disconnect_require_sudo
    Thread.current[:plugin_test_user].sudo = false
    [:connect, :disconnect].each do |action|
      post action
      assert_response :forbidden
    end
  end

  def test_connect_and_disconnect_require_csrf
    Microsoft365SmtpController.allow_forgery_protection = true
    [:connect, :disconnect].each do |action|
      assert_raises(ActionController::InvalidAuthenticityToken) { post action }
    end
  ensure
    Microsoft365SmtpController.allow_forgery_protection = false
  end

  def test_callback_requires_existing_administrator_login
    Thread.current[:plugin_test_user] = nil
    get :callback, params: { state: 'untrusted', code: 'untrusted' }
    assert_response :forbidden
  end

  def test_connect_redirects_only_to_microsoft_with_no_store
    store = MemoryStore.new
    flow = Paytech::RedmineMicrosoft365Smtp::BrowserConnection.new(store: store)
    config = configuration
    @controller.define_singleton_method(:browser_connection) { flow }
    @controller.define_singleton_method(:current_configuration) { config }
    post :connect
    assert_response :redirect
    assert_equal 'login.microsoftonline.com', URI(response.location).host
    assert_equal 'no-store', response.headers['Cache-Control']
    assert_equal 'no-referrer', response.headers['Referrer-Policy']
    assert session[:m365_oauth_state]
  end

  def test_callback_finishes_once_without_sending_or_enabling_delivery
    store = MemoryStore.new
    http = FakeHttp.new([success_response])
    tokens = Paytech::RedmineMicrosoft365Smtp::TokenProvider.new(http_factory: ->(*) { http })
    smtp = FakeSmtp.new
    flow = Paytech::RedmineMicrosoft365Smtp::BrowserConnection.new(store: store, tokens: tokens, smtp_factory: -> { smtp })
    config = configuration
    @controller.define_singleton_method(:browser_connection) { flow }
    @controller.define_singleton_method(:current_configuration) { config }
    flow.start(config, session: session, user_id: 42)
    state = session[:m365_oauth_state]
    get :callback, params: { state: state, code: 'test-code' }
    assert_redirected_to microsoft365_smtp_connection_path
    assert flow.connected?(config)
    assert_nil smtp.sent
    assert_includes flash[:notice], 'No email was sent'
    get :callback, params: { state: state, code: 'test-code' }
    assert_includes flash[:error], 'INVALID_OAUTH_STATE'
    assert_equal 1, http.requests.length
  end

  def test_post_requires_sudo_mode_hook
    Thread.current[:plugin_test_user].sudo = false
    post :create
    assert_response :forbidden
  end

  def test_post_rejects_missing_csrf_token
    Microsoft365SmtpController.allow_forgery_protection = true
    assert_raises(ActionController::InvalidAuthenticityToken) { post :create }
  ensure
    Microsoft365SmtpController.allow_forgery_protection = false
  end

  def test_test_email_goes_only_to_current_admin_ignoring_recipient_parameter
    sent = []
    klass = Paytech::RedmineMicrosoft365Smtp::DeliveryMethod
    original = klass.instance_method(:deliver!)
    klass.define_method(:deliver!) { |message| sent << message }
    post :create, params: { recipient: 'other@example.invalid' }
    assert_response :redirect
    assert_equal 1, sent.length
    assert_equal ['admin@example.invalid'], sent.first.to
    assert_nil sent.first.cc
    assert_nil sent.first.bcc
  ensure
    klass.define_method(:deliver!, original)
  end

  def test_delivery_failure_shows_only_safe_error
    klass = Paytech::RedmineMicrosoft365Smtp::DeliveryMethod
    original = klass.instance_method(:deliver!)
    klass.define_method(:deliver!) { |_message| raise Paytech::RedmineMicrosoft365Smtp::DeliveryError, 'SMTP_AUTH_REJECTED' }
    post :create
    assert_response :redirect
    assert_includes flash[:error], 'SMTP_AUTH_REJECTED'
  ensure
    klass.define_method(:deliver!, original)
  end
end
