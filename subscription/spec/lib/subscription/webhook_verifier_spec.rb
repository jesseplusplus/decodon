# frozen_string_literal: true

require 'rails_helper'
require 'subscription/webhook_verifier'

RSpec.describe Subscription::WebhookVerifier do
  describe '.verify_revenuecat!' do
    let(:webhook_secret) { 'test_secret_key' }
    let(:request_body) { '{"event":{"type":"INITIAL_PURCHASE"}}' }

    before do
      allow(Subscription).to receive(:revenuecat_webhook_secret).and_return(webhook_secret)
    end

    context 'with valid secret' do
      it 'returns true' do
        result = described_class.verify_revenuecat!(
          request_body,
          "Bearer #{webhook_secret}"
        )
        expect(result).to be true
      end
    end

    context 'with invalid secret' do
      it 'raises InvalidSecret error' do
        expect do
          described_class.verify_revenuecat!(
            request_body,
            'Bearer invalid_secret'
          )
        end.to raise_error(Subscription::WebhookVerifier::InvalidSecret, /does not match/)
      end
    end

    context 'with missing secret' do
      it 'raises InvalidSecret error' do
        expect do
          described_class.verify_revenuecat!(request_body, '')
        end.to raise_error(Subscription::WebhookVerifier::InvalidSecret, /Missing secret/)
      end
    end

    context 'with missing Authorization header' do
      it 'raises InvalidSecret error' do
        expect do
          described_class.verify_revenuecat!(request_body, nil)
        end.to raise_error(Subscription::WebhookVerifier::InvalidSecret, /Missing secret/)
      end
    end

    context 'when webhook secret is not configured' do
      before do
        allow(Subscription).to receive(:revenuecat_webhook_secret).and_return(nil)
      end

      it 'raises InvalidSecret error' do
        expect do
          described_class.verify_revenuecat!(
            request_body,
            'Bearer any_secret'
          )
        end.to raise_error(Subscription::WebhookVerifier::InvalidSecret, /Missing secret/)
      end
    end
  end
end
