# frozen_string_literal: true

module Subscription
  class WebhookVerifier
    class InvalidSignature < StandardError; end

    def self.verify_revenuecat!(request_body, authorization_header)
      return true if Subscription.revenuecat_webhook_secret.blank?

      signature = extract_signature(authorization_header)
      raise InvalidSignature, 'Missing signature' if signature.blank?

      expected_signature = compute_signature(request_body)

      raise InvalidSignature, 'Signature does not match' unless secure_compare(signature, expected_signature)

      true
    end

    def self.extract_signature(authorization_header)
      return nil if authorization_header.blank?

      # RevenueCat sends: "Bearer <signature>"
      authorization_header.sub(/^Bearer /, '')
    end

    def self.compute_signature(body)
      OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new('sha256'),
        Subscription.revenuecat_webhook_secret,
        body
      )
    end

    def self.secure_compare(signature, expected_signature)
      return false if signature.blank? || expected_signature.blank? || signature.bytesize != expected_signature.bytesize

      signature_bytes = signature.bytes.to_a
      expected_signature_bytes = expected_signature.bytes.to_a

      signature_bytes.each_with_index.all? do |byte, index|
        byte == expected_signature_bytes[index]
      end
    end
  end
end
