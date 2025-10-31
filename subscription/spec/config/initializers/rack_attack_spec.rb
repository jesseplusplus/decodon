# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rack::Attack for RevenueCat invite lookup', type: :request do
  let(:customer_id) { SecureRandom.uuid }
  let(:invite) { Fabricate(:invite, max_uses: 5, uses: 0) }
  # rubocop:disable RSpec/LetSetup
  let!(:subscription) do
    Fabricate(:revenuecat_subscription,
              revenuecat_customer_id: customer_id,
              status: 'active',
              expires_at: 1.month.from_now,
              invite: invite)
  end
  # rubocop:enable RSpec/LetSetup

  before do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  after do
    Rack::Attack.cache.store.clear
  end

  describe 'throttle_revenuecat_invite_lookup' do
    let(:limit) { 10 }

    context 'when number of requests is lower than the limit' do
      it 'does not throttle' do
        limit.times do
          get "/subscription/api/subscription_invites/#{customer_id}"
          expect(response).to_not have_http_status(429)
        end
      end
    end

    context 'when number of requests exceeds the limit' do
      it 'throttles requests after the limit' do
        (limit + 1).times do |i|
          get "/subscription/api/subscription_invites/#{customer_id}"

          if i < limit
            expect(response).to_not have_http_status(429)
          else
            expect(response).to have_http_status(429)
            expect(response.headers['X-RateLimit-Limit']).to eq(limit.to_s)
            expect(response.headers['X-RateLimit-Remaining']).to eq('0')
          end
        end
      end
    end

    context 'when requests are for different customer IDs' do
      let(:other_customer_id) { SecureRandom.uuid }

      it 'does not throttle requests with different customer IDs' do
        limit.times do
          get "/subscription/api/subscription_invites/#{customer_id}"
          expect(response).to_not have_http_status(429)
        end

        # Request with different customer ID should not be throttled
        get "/subscription/api/subscription_invites/#{other_customer_id}"
        expect(response).to_not have_http_status(429)
      end
    end
  end
end
