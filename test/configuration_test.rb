# frozen_string_literal: true

require_relative 'test_helper'

class ConfigurationTest < Minitest::Test
  include PluginTestSupport

  def test_defaults_are_disabled
    refute Paytech::RedmineMicrosoft365Smtp::Configuration.new({}).enabled?
  end

  def test_valid_configuration_and_secret
    config = configuration.validate!
    assert_equal 15, config.open_timeout
    assert_equal 30, config.read_timeout
    assert_equal 'unit-test-secret', config.client_secret
    refute_includes config.inspect, 'unit-test-secret'
  end

  def test_rejects_bad_identifiers_and_header_injection
    [{ 'tenant_id' => 'organizations' }, { 'client_id' => '../other' },
     { 'mailbox' => "sender@example.invalid\r\nBcc: other@example.invalid" },
     { 'sender_name' => "Redmine\nBcc:" }, { 'helo_domain' => "a\r\nMAIL FROM:" },
     { 'open_timeout' => '0' }, { 'read_timeout' => '121' }].each do |overrides|
      assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { configuration(overrides).validate! }
    end
  end

  def test_missing_secret_fails
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { configuration(environment: {}).client_secret }
  end

  def test_secret_file_and_permissions
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'secret')
      File.write(path, "file-secret\n", mode: 'w', perm: 0o600)
      config = configuration(environment: { 'REDMINE_M365_CLIENT_SECRET_FILE' => path })
      assert_equal 'file-secret', config.client_secret
      File.chmod(0o644, path)
      error = assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { config.client_secret }
      assert_equal 'UNSAFE_SECRET_FILE', error.code
    end
  end

  def test_missing_file_does_not_fall_back_to_environment_secret
    config = configuration(environment: { 'REDMINE_M365_CLIENT_SECRET_FILE' => '/not-present/m365-test',
                                           'REDMINE_M365_CLIENT_SECRET' => 'must-not-use' })
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { config.client_secret }
  end

  def test_secret_file_symlink_rejected
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'secret')
      File.write(path, 'file-secret', mode: 'w', perm: 0o600)
      linked = File.join(directory, 'link')
      File.symlink(path, linked)
      assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) do
        configuration(environment: { 'REDMINE_M365_CLIENT_SECRET_FILE' => linked }).client_secret
      end
    end
  end
end
