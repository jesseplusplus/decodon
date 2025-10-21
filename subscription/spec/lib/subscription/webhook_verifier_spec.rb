# frozen_string_literal: true

require 'rails_helper'
require 'subscription/webhook_verifier'

RSpec.describe Subscription::WebhookVerifier do
  describe '.verify_revenuecat!' do
    let(:webhook_secret) { 'test_secret_key' }
    let(:request_body) { '{"event":{"type":"INITIAL_PURCHASE"}}' }
    let(:valid_signature) do
      OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new('sha256'),
        webhook_secret,
        request_body
      )
    end

    before do
      allow(Subscription).to receive(:revenuecat_webhook_secret).and_return(webhook_secret)
    end

    context 'with valid signature' do
      it 'returns true' do
        result = described_class.verify_revenuecat!(
          request_body,
          "Bearer #{valid_signature}"
        )
        expect(result).to be true
      end
    end

    context 'with invalid signature' do
      it 'raises InvalidSignature error' do
        expect do
          described_class.verify_revenuecat!(
            request_body,
            'Bearer invalid_signature'
          )
        end.to raise_error(Subscription::WebhookVerifier::InvalidSignature, /does not match/)
      end
    end

    context 'with missing signature' do
      it 'raises InvalidSignature error' do
        expect do
          described_class.verify_revenuecat!(request_body, '')
        end.to raise_error(Subscription::WebhookVerifier::InvalidSignature, /Missing signature/)
      end
    end

    context 'with missing Authorization header' do
      it 'raises InvalidSignature error' do
        expect do
          described_class.verify_revenuecat!(request_body, nil)
        end.to raise_error(Subscription::WebhookVerifier::InvalidSignature, /Missing signature/)
      end
    end

    context 'when webhook secret is not configured' do
      before do
        allow(Subscription).to receive(:revenuecat_webhook_secret).and_return(nil)
      end

      it 'returns true without verification' do
        result = described_class.verify_revenuecat!(
          request_body,
          'Bearer any_signature'
        )
        expect(result).to be true
      end
    end

    context 'with different request body' do
      it 'fails verification' do
        expect do
          described_class.verify_revenuecat!(
            '{"different":"body"}',
            "Bearer #{valid_signature}"
          )
        end.to raise_error(Subscription::WebhookVerifier::InvalidSignature)
      end
    end
  end
end
