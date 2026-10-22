# frozen_string_literal: true

require_relative 'test_helper'

class GrantStoreTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    @key = SecureRandom.random_bytes(32)
    @store = Paytech::RedmineMicrosoft365Smtp::GrantStore.new(directory: @directory, key: @key)
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_authenticated_encryption_permissions_and_cross_instance_persistence
    @store.synchronize { |_document, save| save.call('grant' => { 'refresh_token' => 'very-private-token' }) }
    path = File.join(@directory, 'grant.enc')
    refute_includes File.read(path), 'very-private-token'
    assert_equal 0o600, File.stat(path).mode & 0o777
    other = Paytech::RedmineMicrosoft365Smtp::GrantStore.new(directory: @directory, key: @key)
    other.synchronize { |document, _save| assert_equal 'very-private-token', document.dig('grant', 'refresh_token') }
    wrong_key = Paytech::RedmineMicrosoft365Smtp::GrantStore.new(directory: @directory, key: SecureRandom.random_bytes(32))
    error = assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { wrong_key.synchronize {} }
    assert_nil error.cause
  end

  def test_concurrent_updates_are_serialized
    threads = 10.times.map do
      Thread.new do
        store = Paytech::RedmineMicrosoft365Smtp::GrantStore.new(directory: @directory, key: @key)
        store.synchronize { |document, save| document['count'] = document.fetch('count', 0) + 1; save.call(document) }
      end
    end
    threads.each(&:value)
    @store.synchronize { |document, _save| assert_equal 10, document['count'] }
  end

  def test_unsafe_directory_permissions_and_symlink_are_rejected
    File.chmod(0o755, @directory)
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { @store.synchronize {} }
    File.chmod(0o700, @directory)
    File.symlink('/dev/null', File.join(@directory, 'grant.enc'))
    assert_raises(Paytech::RedmineMicrosoft365Smtp::ConfigurationError) { @store.synchronize {} }
  end
end
