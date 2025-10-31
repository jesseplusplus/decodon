# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subscription::RevenuecatSubscription do
  describe 'associations' do
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to belong_to(:invite).optional }
    it { is_expected.to have_many(:members) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:revenuecat_customer_id) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe '#active?' do
    context 'when status is active and not expired' do
      let(:subscription) do
        Fabricate.build(:revenuecat_subscription, status: 'active', expires_at: 1.day.from_now)
      end

      it 'returns true' do
        expect(subscription.active?).to be true
      end
    end

    context 'when status is trialing and not expired' do
      let(:subscription) do
        Fabricate.build(:revenuecat_subscription, status: 'trialing', expires_at: 1.day.from_now)
      end

      it 'returns true' do
        expect(subscription.active?).to be true
      end
    end

    context 'when status is expired' do
      let(:subscription) do
        Fabricate.build(:revenuecat_subscription, status: 'expired', expires_at: 1.day.ago)
      end

      it 'returns false' do
        expect(subscription.active?).to be false
      end
    end

    context 'when subscription has expired based on date' do
      let(:subscription) do
        Fabricate.build(:revenuecat_subscription, status: 'active', expires_at: 1.day.ago)
      end

      it 'returns false' do
        expect(subscription.active?).to be false
      end
    end
  end

  describe '#trialing?' do
    it 'returns true when status is trialing' do
      subscription = Fabricate.build(:revenuecat_subscription, status: 'trialing')
      expect(subscription.trialing?).to be true
    end

    it 'returns false when status is not trialing' do
      subscription = Fabricate.build(:revenuecat_subscription, status: 'active')
      expect(subscription.trialing?).to be false
    end
  end

  describe '#description' do
    it 'returns the product name from configuration' do
      subscription = Fabricate.build(:revenuecat_subscription, product_id: 'rc_monthly_individual')
      expect(subscription.description).to eq('Individual Monthly')
    end

    it 'returns the product_id when not in configuration' do
      subscription = Fabricate.build(:revenuecat_subscription, product_id: 'unknown_product')
      expect(subscription.description).to eq('unknown_product')
    end
  end

  describe '#size' do
    it 'returns the quantity' do
      subscription = Fabricate.build(:revenuecat_subscription, quantity: 5)
      expect(subscription.size).to eq(5)
    end

    it 'returns 1 when quantity is nil' do
      subscription = Fabricate.build(:revenuecat_subscription, quantity: nil)
      expect(subscription.size).to eq(1)
    end
  end

  describe '#provider' do
    it 'returns "App Store" for app_store' do
      subscription = Fabricate.build(:revenuecat_subscription, store: 'app_store')
      expect(subscription.provider).to eq('App Store')
    end

    it 'returns "Google Play" for play_store' do
      subscription = Fabricate.build(:revenuecat_subscription, store: 'play_store')
      expect(subscription.provider).to eq('Google Play')
    end

    it 'returns titleized store name for other stores' do
      subscription = Fabricate.build(:revenuecat_subscription, store: 'stripe')
      expect(subscription.provider).to eq('Stripe')
    end
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_sub) { Fabricate(:revenuecat_subscription, status: 'active', expires_at: 1.day.from_now) }
      let!(:trialing_sub) { Fabricate(:revenuecat_subscription, status: 'trialing', expires_at: 1.day.from_now) }
      let!(:expired_sub) { Fabricate(:revenuecat_subscription, status: 'expired', expires_at: 1.day.ago) }
      let!(:canceled_sub) { Fabricate(:revenuecat_subscription, status: 'canceled', expires_at: 1.day.from_now) }

      it 'returns only active and trialing subscriptions that have not expired' do
        expect(described_class.active).to contain_exactly(active_sub, trialing_sub)
        expect(expired_sub).to be_persisted
        expect(canceled_sub).to be_persisted
      end
    end
  end
end
