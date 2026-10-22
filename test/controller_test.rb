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
  Account = Struct.new(:mail, :admin, :sudo)

  def self.current
    Thread.current[:plugin_test_user]
  end
end

require_relative '../app/controllers/microsoft365_smtp_controller'

class ControllerTest < ActionController::TestCase
  tests Microsoft365SmtpController

  def setup
    super
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get 'admin/microsoft365_smtp/test', to: 'microsoft365_smtp#show', as: :microsoft365_smtp_test
      post 'admin/microsoft365_smtp/test', to: 'microsoft365_smtp#create'
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
