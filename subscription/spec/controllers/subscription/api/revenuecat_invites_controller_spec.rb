# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/LetSetup
RSpec.describe Subscription::Api::RevenuecatInvitesController do
  routes { Subscription::Engine.routes }

  describe 'GET #show' do
    let(:customer_id) { SecureRandom.uuid }

    context 'when subscription exists and is active' do
      let(:invite) { Fabricate(:invite, max_uses: 5, uses: 0) }
      let!(:subscription) do
        Fabricate(:revenuecat_subscription, revenuecat_customer_id: customer_id,
                                            status: 'active',
                                            expires_at: 1.month.from_now,
                                            invite: invite)
      end

      it 'returns the invite code' do
        get :show, params: { revenuecat_customer_id: customer_id }

        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        expect(json['invite_code']).to eq(invite.code)
        expect(json['status']).to eq('active')
        expect(json['provider']).to eq('App Store')
      end
    end

    context 'when subscription is trialing' do
      let(:invite) { Fabricate(:invite, max_uses: 1) }
      let!(:subscription) do
        Fabricate(:revenuecat_subscription, revenuecat_customer_id: customer_id,
                                            status: 'trialing',
                                            expires_at: 7.days.from_now,
                                            trial_ends_at: 7.days.from_now,
                                            invite: invite)
      end

      it 'returns the invite code' do
        get :show, params: { revenuecat_customer_id: customer_id }

        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        expect(json['invite_code']).to eq(invite.code)
        expect(json['status']).to eq('trialing')
      end
    end

    context 'when subscription does not exist yet' do
      it 'returns processing status' do
        get :show, params: { revenuecat_customer_id: 'unknown_customer' }

        expect(response).to have_http_status(202)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('processing')
      end
    end

    context 'when subscription is expired' do
      let!(:subscription) do
        Fabricate(:revenuecat_subscription, revenuecat_customer_id: customer_id,
                                            status: 'expired',
                                            expires_at: 1.day.ago)
      end

      it 'returns error' do
        get :show, params: { revenuecat_customer_id: customer_id }

        expect(response).to have_http_status(422)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Subscription not active')
      end
    end

    context 'when invite is fully used' do
      let(:invite) { Fabricate(:invite, max_uses: 1, uses: 1) }
      let!(:subscription) do
        Fabricate(:revenuecat_subscription, revenuecat_customer_id: customer_id,
                                            status: 'active',
                                            expires_at: 1.month.from_now,
                                            invite: invite)
      end

      it 'returns error' do
        get :show, params: { revenuecat_customer_id: customer_id }

        expect(response).to have_http_status(422)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Invite code has been fully used')
      end
    end

    context 'when subscription has no invite' do
      let!(:subscription) do
        Fabricate(:revenuecat_subscription, revenuecat_customer_id: customer_id,
                                            status: 'active',
                                            expires_at: 1.month.from_now,
                                            invite: nil)
      end

      it 'returns 404' do
        get :show, params: { revenuecat_customer_id: customer_id }

        expect(response).to have_http_status(404)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('No invite associated with subscription')
      end
    end
  end
end
# rubocop:enable RSpec/LetSetup
