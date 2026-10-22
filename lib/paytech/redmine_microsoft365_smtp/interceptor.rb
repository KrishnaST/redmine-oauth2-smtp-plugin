# frozen_string_literal: true

module Paytech::RedmineMicrosoft365Smtp
  class Interceptor
    def self.delivering_email(message)
      return unless Configuration.current.enabled?
      # Choose at delivery time, including mail assembled by existing queued jobs.
      message.delivery_method(DeliveryMethod)
    end
  end
end
