# frozen_string_literal: true

require 'action_controller'
require 'action_mailer'
require 'rails'
require_relative 'test_helper'

class FrameworkTest < Minitest::Test
  def test_paytech_namespace_identifier
    assert_equal 'com.paytech', Paytech::ORGANIZATION_IDENTIFIER
    assert_equal 'Paytech::RedmineMicrosoft365Smtp::DeliveryMethod', Paytech::RedmineMicrosoft365Smtp::DeliveryMethod.name
  end
  def test_delivery_method_registers_with_installed_action_mailer
    ActionMailer::Base.add_delivery_method(:redmine_microsoft365_smtp, Paytech::RedmineMicrosoft365Smtp::DeliveryMethod)
    assert_equal Paytech::RedmineMicrosoft365Smtp::DeliveryMethod, ActionMailer::Base.delivery_methods[:redmine_microsoft365_smtp]
    ActionMailer::Base.register_interceptor(Paytech::RedmineMicrosoft365Smtp::Interceptor)
    ActionMailer::Base.unregister_interceptor(Paytech::RedmineMicrosoft365Smtp::Interceptor)
  end

  def test_routes_are_admin_get_and_post_only
    require 'action_dispatch'
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw do
      instance_eval(File.read(File.expand_path('../config/routes.rb', __dir__)))
    end
    assert_equal ['GET', 'POST', 'GET', 'POST', 'GET', 'POST'], routes.routes.map(&:verb)
    assert routes.routes.all? { |route| route.path.spec.to_s.start_with?('/admin/microsoft365_smtp/') }
    assert_equal '/admin/microsoft365_smtp/test', routes.url_helpers.microsoft365_smtp_test_path
  end

  def test_plugin_entrypoint_is_valid_and_reloading_does_not_duplicate_interceptor
    Object.const_set(:Redmine, Module.new) unless defined?(Redmine)
    registry = Class.new do
      attr_reader :values

      def initialize
        @values = {}
      end

      def method_missing(name, *arguments, **keywords)
        @values[name] = [arguments, keywords]
      end

      def respond_to_missing?(_name, _include_private = false)
        true
      end
    end.new
    plugin = Module.new
    plugin.define_singleton_method(:register) { |_name, &block| registry.instance_eval(&block) }
    Redmine.const_set(:Plugin, plugin)
    2.times { load File.expand_path('../init.rb', __dir__) }
    assert_equal '2.0.3', registry.values[:version].first.first
    assert_equal '0', registry.values[:settings].last[:default]['enabled']
    assert_equal 1, Mail.class_variable_get(:@@delivery_interceptors).count(Paytech::RedmineMicrosoft365Smtp::Interceptor)
  ensure
    ActionMailer::Base.unregister_interceptor(Paytech::RedmineMicrosoft365Smtp::Interceptor)
    Redmine.send(:remove_const, :Plugin) if Redmine.const_defined?(:Plugin)
  end

  def test_settings_offer_direct_csrf_protected_post_without_nested_forms
    template = File.read(File.expand_path('../app/views/settings/_microsoft365_smtp.html.erb', __dir__))
    assert_includes template, "link_to 'Connect Microsoft', microsoft365_smtp_connect_path, method: :post"
    refute_match(/<form\b|form_tag|button_to/, template)
    assert_includes template, 'Save settings first'
    ['redirect_uri', 'helo_domain', 'open_timeout', 'read_timeout'].each do |name|
      refute_includes template, "['#{name}',"
    end
  end
end
