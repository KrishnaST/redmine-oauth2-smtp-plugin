# frozen_string_literal: true

require_relative 'test_helper'

class InterceptorTest < Minitest::Test
  include PluginTestSupport

  def with_configuration(config)
    klass = Paytech::RedmineMicrosoft365Smtp::Configuration
    original = klass.method(:current)
    klass.define_singleton_method(:current) { config }
    yield
  ensure
    klass.define_singleton_method(:current, original)
  end

  def test_disabled_plugin_preserves_existing_delivery_method
    mail = Mail.new
    mail.delivery_method(:test)
    with_configuration(configuration({ 'enabled' => '0' })) do
      Paytech::RedmineMicrosoft365Smtp::Interceptor.delivering_email(mail)
      assert_instance_of Mail::TestMailer, mail.delivery_method
    end
  end

  def test_enabled_plugin_selects_oauth_delivery
    mail = Mail.new
    with_configuration(configuration) do
      Paytech::RedmineMicrosoft365Smtp::Interceptor.delivering_email(mail)
      assert_instance_of Paytech::RedmineMicrosoft365Smtp::DeliveryMethod, mail.delivery_method
    end
  end
end
