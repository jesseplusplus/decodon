# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subscription::RevenuecatWebhookWorker, type: :worker do
  let(:worker) { described_class.new }

  before do
    allow(Subscription).to receive(:revenuecat_products).and_return({
      'rc_monthly_individual' => { 'name' => 'Individual Monthly', 'max_uses' => 1 },
    })
  end

  describe '#perform' do
    context 'when handling INITIAL_PURCHASE event' do
      let(:event) do
        {
          'event' => {
            'type' => 'INITIAL_PURCHASE',
            'app_user_id' => 'anonymous_user_123',
            'original_app_user_id' => 'anonymous_user_123',
            'original_transaction_id' => 'txn_123abc',
            'product_id' => 'rc_monthly_individual',
            'period_type' => 'NORMAL',
            'purchased_at_ms' => Time.current.to_i * 1000,
            'expiration_at_ms' => 1.month.from_now.to_i * 1000,
            'store' => 'APP_STORE',
            'environment' => 'PRODUCTION',
          },
        }.to_json
      end

      it 'creates a new subscription and invite' do
        instance_user = Fabricate(:user)
        account = instance_double(Account, user: instance_user)
        contact = instance_double(InstancePresenter::ContactPresenter, account: account)
        presenter = instance_double(InstancePresenter, contact: contact)
        allow(InstancePresenter).to receive(:new).and_return(presenter)

        expect do
          worker.perform(event)
        end.to change(Subscription::RevenuecatSubscription, :count).by(1)
                                                                   .and change(Invite, :count).by(1)

        subscription = Subscription::RevenuecatSubscription.last
        expect(subscription.revenuecat_customer_id).to eq('anonymous_user_123')
        expect(subscription.subscription_id).to eq('txn_123abc')
        expect(subscription.status).to eq('active')
        expect(subscription.invite).to be_present
      end

      it 'is idempotent' do
        instance_user = Fabricate(:user)
        account = instance_double(Account, user: instance_user)
        contact = instance_double(InstancePresenter::ContactPresenter, account: account)
        presenter = instance_double(InstancePresenter, contact: contact)
        allow(InstancePresenter).to receive(:new).and_return(presenter)

        worker.perform(event)

        expect do
          worker.perform(event)
        end.to_not change(Subscription::RevenuecatSubscription, :count)
      end
    end

    context 'when handling INITIAL_PURCHASE with trial period' do
      let(:event) do
        {
          'event' => {
            'type' => 'INITIAL_PURCHASE',
            'app_user_id' => 'anonymous_user_456',
            'original_app_user_id' => 'anonymous_user_456',
            'original_transaction_id' => 'txn_456def',
            'product_id' => 'rc_monthly_individual',
            'period_type' => 'TRIAL',
            'purchased_at_ms' => Time.current.to_i * 1000,
            'expiration_at_ms' => 7.days.from_now.to_i * 1000,
            'store' => 'APP_STORE',
            'environment' => 'SANDBOX',
          },
        }.to_json
      end

      it 'creates subscription with trialing status' do
        instance_user = Fabricate(:user)
        account = instance_double(Account, user: instance_user)
        contact = instance_double(InstancePresenter::ContactPresenter, account: account)
        presenter = instance_double(InstancePresenter, contact: contact)
        allow(InstancePresenter).to receive(:new).and_return(presenter)

        worker.perform(event)

        subscription = Subscription::RevenuecatSubscription.last
        expect(subscription.status).to eq('trialing')
        expect(subscription.trial_ends_at).to be_present
        expect(subscription.environment).to eq('sandbox')
      end
    end

    context 'when handling RENEWAL event' do
      let!(:subscription) do
        Fabricate(:revenuecat_subscription,
                  subscription_id: 'txn_789ghi',
                  status: 'trialing',
                  expires_at: 1.day.ago)
      end

      let(:event) do
        {
          'event' => {
            'type' => 'RENEWAL',
            'app_user_id' => subscription.revenuecat_customer_id,
            'original_app_user_id' => 'anonymous_user_789',
            'original_transaction_id' => 'txn_789ghi',
            'product_id' => 'rc_monthly_individual',
            'period_type' => 'NORMAL',
            'purchased_at_ms' => Time.current.to_i * 1000,
            'expiration_at_ms' => 1.month.from_now.to_i * 1000,
            'store' => 'APP_STORE',
            'environment' => 'PRODUCTION',
          },
        }.to_json
      end

      it 'updates expiration date and status' do
        worker.perform(event)

        subscription.reload
        expect(subscription.status).to eq('active')
        expect(subscription.expires_at).to be > Time.current
        expect(subscription.trial_ends_at).to be_nil
      end
    end

    context 'when handling CANCELLATION event' do
      let!(:subscription) do
        Fabricate(:revenuecat_subscription,
                  subscription_id: 'txn_cancel',
                  status: 'active',
                  user: Fabricate(:user))
      end

      let(:event) do
        {
          'event' => {
            'type' => 'CANCELLATION',
            'app_user_id' => subscription.revenuecat_customer_id,
            'original_app_user_id' => 'anonymous_user_789',
            'original_transaction_id' => 'txn_cancel',
            'product_id' => 'rc_monthly_individual',
            'cancel_at_ms' => Time.current.to_i * 1000,
            'expiration_at_ms' => 1.month.from_now.to_i * 1000,
            'store' => 'APP_STORE',
            'environment' => 'PRODUCTION',
          },
        }.to_json
      end

      it 'updates status to canceled' do
        worker.perform(event)

        subscription.reload
        expect(subscription.status).to eq('canceled')
      end
    end

    context 'when handling TRANSFER event' do
      let!(:user) { Fabricate(:user) }
      let!(:invite) { Fabricate(:invite, user: user) }
      let!(:subscription) do
        Fabricate(:revenuecat_subscription,
                  revenuecat_customer_id: 'old_customer_id',
                  invite: invite,
                  user_id: nil)
      end

      let(:event) do
        {
          'event' => {
            'type' => 'TRANSFER',
            'transferred_from' => ['old_customer_id'],
            'transferred_to' => [user.id.to_s],
          },
        }.to_json
      end

      it 'transfers subscription to user' do
        worker.perform(event)

        subscription.reload
        expect(subscription.revenuecat_customer_id).to eq('old_customer_id')
        expect(subscription.user_id).to eq(user.id)
      end
    end

    context 'when event is from Stripe store' do
      let(:event) do
        {
          'event' => {
            'type' => 'INITIAL_PURCHASE',
            'store' => 'STRIPE',
            'app_user_id' => 'user_123',
          },
        }.to_json
      end

      it 'ignores the event' do
        expect do
          worker.perform(event)
        end.to_not change(Subscription::RevenuecatSubscription, :count)
      end
    end
  end
end
