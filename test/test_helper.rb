# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/paytech/redmine_microsoft365_smtp'

module PluginTestSupport
  def configuration(overrides = {}, environment: { 'REDMINE_M365_CLIENT_SECRET' => 'unit-test-secret' })
    Paytech::RedmineMicrosoft365Smtp::Configuration.new({
      'enabled' => '1', 'tenant_id' => '11111111-1111-1111-1111-111111111111',
      'client_id' => '22222222-2222-2222-2222-222222222222',
      'mailbox' => 'redmine@example.invalid', 'helo_domain' => 'redmine.example.invalid',
      'redirect_uri' => 'https://redmine.example.invalid/admin/microsoft365_smtp/callback'
    }.merge(overrides), environment: environment)
  end

  def success_response(token: 'test-access-token', lifetime: 3600, refresh: 'test-refresh-token')
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    response.define_singleton_method(:body) do
      JSON.generate('access_token' => token, 'expires_in' => lifetime, 'token_type' => 'Bearer',
                    'refresh_token' => refresh, 'scope' => 'https://outlook.office.com/SMTP.Send')
    end
    response
  end

  class FakeHttp
    attr_accessor :use_ssl, :verify_mode, :min_version, :open_timeout, :read_timeout, :write_timeout
    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def request(request)
      @requests << request
      response = @responses.length > 1 ? @responses.shift : @responses.first
      response.define_singleton_method(:read_body) { |&block| block.call(body) }
      yield response if block_given?
      response
    end
  end

  class FakeTokens
    attr_reader :invalidations

    def initialize
      @invalidations = 0
    end

    def access_token(_configuration)
      'test-access-token'
    end

    def invalidate!
      @invalidations += 1
    end
  end

  class MemoryStore
    attr_reader :document

    def initialize(document = {})
      @document = document
      @mutex = Mutex.new
    end

    def synchronize
      @mutex.synchronize do
        working = Marshal.load(Marshal.dump(@document))
        yield working, ->(value) { @document = Marshal.load(Marshal.dump(value)) }
      end
    end
  end

  class FakeSmtp
    attr_accessor :open_timeout, :read_timeout, :failure
    attr_reader :context, :start_arguments, :sent

    def enable_starttls(context)
      @context = context
    end

    def start(*arguments)
      @start_arguments = arguments
      raise failure if failure
      yield self
    end

    def sendmail(*arguments)
      @sent = arguments
    end
  end
end
