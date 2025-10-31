# frozen_string_literal: true

module Subscription
  class WebhookVerifier
    class InvalidSecret < StandardError; end

    def self.verify_revenuecat!(_request_body, authorization_header)
      raise InvalidSecret, 'Missing secret' if Subscription.revenuecat_webhook_secret.blank?

      secret = extract_secret(authorization_header)
      raise InvalidSecret, 'Missing secret' if secret.blank?

      match = secure_compare(secret, Subscription.revenuecat_webhook_secret)
      raise InvalidSecret, 'Secret does not match' unless match

      match
    end

    def self.extract_secret(authorization_header)
      return nil if authorization_header.blank?

      authorization_header.sub(/^Bearer /, '')
    end

    def self.secure_compare(secret, expected_secret)
      return false if secret.blank? || expected_secret.blank?

      ActiveSupport::SecurityUtils.secure_compare(secret, expected_secret)
    end
  end
end
