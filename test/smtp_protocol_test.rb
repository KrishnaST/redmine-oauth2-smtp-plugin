# frozen_string_literal: true

require 'socket'
require_relative 'test_helper'

class SmtpProtocolTest < Minitest::Test
  include PluginTestSupport

  def test_real_net_smtp_refuses_server_without_starttls
    listener = TCPServer.new('127.0.0.1', 0)
    commands = []
    server = Thread.new do
      socket = listener.accept
      socket.write("220 test.invalid ESMTP\r\n")
      commands << socket.gets
      socket.write("250-test.invalid\r\n250 AUTH XOAUTH2\r\n")
      while (line = socket.gets)
        commands << line
        break
      end
    ensure
      socket&.close
    end
    transport = Paytech::RedmineMicrosoft365Smtp::DeliveryMethod.new(
      configuration_provider: -> { configuration }, token_provider: FakeTokens.new,
      smtp_factory: -> { Net::SMTP.new('127.0.0.1', listener.addr[1]) }
    )
    mail = Mail.new(from: 'sender@example.invalid', to: 'recipient@example.invalid', body: 'test')
    assert_raises(Paytech::RedmineMicrosoft365Smtp::DeliveryError) { transport.deliver!(mail) }
    assert server.join(5), 'fake SMTP server must terminate'
    refute commands.any? { |command| command.start_with?('AUTH', 'MAIL', 'DATA') }
  ensure
    listener&.close
    server&.kill if server&.alive?
  end

  def test_real_starttls_and_xoauth2_message_submission_on_loopback
    key = OpenSSL::PKey::RSA.new(2048)
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = 1
    certificate.subject = OpenSSL::X509::Name.parse('/CN=localhost')
    certificate.issuer = certificate.subject
    certificate.public_key = key.public_key
    certificate.not_before = Time.now - 60
    certificate.not_after = Time.now + 3600
    extensions = OpenSSL::X509::ExtensionFactory.new
    extensions.subject_certificate = certificate
    extensions.issuer_certificate = certificate
    certificate.add_extension(extensions.create_extension('subjectAltName', 'IP:127.0.0.1'))
    certificate.add_extension(extensions.create_extension('basicConstraints', 'CA:TRUE', true))
    certificate.sign(key, OpenSSL::Digest.new('SHA256'))
    context = OpenSSL::SSL::SSLContext.new
    context.cert = certificate
    context.key = key
    listener = TCPServer.new('127.0.0.1', 0)
    authentication = nil
    captured = []
    commands = []
    server = Thread.new do
      raw = listener.accept
      raw.write("220 test.invalid ESMTP\r\n")
      commands << raw.gets
      raw.write("250-test.invalid\r\n250 STARTTLS\r\n")
      commands << raw.gets
      raw.write("220 Ready for TLS\r\n")
      socket = OpenSSL::SSL::SSLSocket.new(raw, context)
      socket.sync_close = true
      socket.accept
      commands << socket.gets
      socket.write("250-test.invalid\r\n250 AUTH XOAUTH2\r\n")
      authentication = socket.gets
      socket.write("235 Authentication successful\r\n")
      loop do
        command = socket.gets
        break unless command
        commands << command
        case command
        when /\AMAIL FROM:/, /\ARCPT TO:/
          socket.write("250 OK\r\n")
        when /\ADATA/
          socket.write("354 End with dot\r\n")
          while (line = socket.gets) && line != ".\r\n"
            captured << line
          end
          socket.write("250 Message accepted\r\n")
        when /\AQUIT/
          socket.write("221 Bye\r\n")
          break
        else
          raise 'Unexpected local SMTP test command'
        end
      end
    ensure
      socket&.close
      raw&.close unless raw&.closed?
    end
    factory = lambda do
      smtp = Net::SMTP.new('127.0.0.1', listener.addr[1])
      smtp.define_singleton_method(:enable_starttls) do |tls_context|
        # Add only the local test certificate; production always uses system trust.
        store = OpenSSL::X509::Store.new
        store.add_cert(certificate)
        tls_context.cert_store = store
        super(tls_context)
      end
      smtp
    end
    transport = Paytech::RedmineMicrosoft365Smtp::DeliveryMethod.new(
      configuration_provider: -> { configuration }, token_provider: FakeTokens.new, smtp_factory: factory
    )
    mail = Mail.new(from: 'sender@example.invalid', to: 'recipient@example.invalid', bcc: 'hidden@example.invalid', subject: 'Protocol test', body: 'Loopback only.')
    transport.deliver!(mail)
    assert server.join(5), 'fake SMTP server must terminate'
    assert_match(/\AAUTH XOAUTH2 /, authentication)
    assert_equal "user=redmine@example.invalid\x01auth=Bearer test-access-token\x01\x01", authentication.split.last.unpack1('m0')
    assert commands.any? { |command| command.start_with?('RCPT TO:<hidden@example.invalid>') }
    refute_match(/^Bcc:/i, captured.join)
    assert_includes captured.join, 'Loopback only.'
  ensure
    listener&.close
    server&.kill if server&.alive?
  end
end
