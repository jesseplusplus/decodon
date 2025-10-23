# frozen_string_literal: true

require 'rails_helper'
require 'subscription/webhook_verifier'

RSpec.describe Subscription::RevenuecatWebhooksController do
  routes { Subscription::Engine.routes }

  describe 'POST #receive' do
    let(:webhook_payload) { { event: { type: 'INITIAL_PURCHASE' } }.to_json }
    let(:valid_signature) { 'valid_signature_token' }

    before do
      allow(Subscription).to receive(:revenuecat_webhook_secret).and_return('test_secret')
    end

    context 'with valid signature' do
      before do
        allow(Subscription::WebhookVerifier).to receive(:verify_revenuecat!)
          .and_return(true)
        allow(Subscription::RevenuecatWebhookWorker).to receive(:perform_async)
      end

      it 'enqueues the webhook worker' do
        request.headers['Authorization'] = "Bearer #{valid_signature}"
        post :receive, body: webhook_payload, as: :json

        expect(response).to have_http_status(201)
        expect(Subscription::RevenuecatWebhookWorker).to have_received(:perform_async)
      end
    end

    context 'with invalid signature' do
      before do
        allow(Subscription::WebhookVerifier).to receive(:verify_revenuecat!)
          .and_raise(Subscription::WebhookVerifier::InvalidSecret.new('Invalid'))
      end

      it 'returns unauthorized' do
        request.headers['Authorization'] = 'Bearer invalid_signature'
        post :receive, body: webhook_payload, as: :json

        expect(response).to have_http_status(401)
      end

      it 'does not enqueue the worker' do
        allow(Subscription::RevenuecatWebhookWorker).to receive(:perform_async)

        request.headers['Authorization'] = 'Bearer invalid_signature'
        post :receive, body: webhook_payload, as: :json

        expect(Subscription::RevenuecatWebhookWorker).to_not have_received(:perform_async)
      end
    end

    context 'without signature' do
      before do
        allow(Subscription::WebhookVerifier).to receive(:verify_revenuecat!)
          .and_raise(Subscription::WebhookVerifier::InvalidSecret.new('Missing'))
      end

      it 'returns unauthorized' do
        post :receive, body: webhook_payload, as: :json

        expect(response).to have_http_status(401)
      end
    end
  end
end
