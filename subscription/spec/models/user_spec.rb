require 'rails_helper'

describe User do
  before do
    stub_request(:post, 'https://api.revenuecat.com/v1/receipts').to_return(status: 200, body: "", headers: {})
  end

  it 'does not associate a subscription when there is no invite associated with the user' do
    invite = Fabricate(:invite)
    subscription = Fabricate(:stripe_subscription, invite: invite)
    user = Fabricate(:user)

    expect(subscription.reload.user).to be_nil
  end

  it 'does not associate a subscription when the invite is not associated with any subscription' do
    invite = Fabricate(:invite)
    subscription = Fabricate(:stripe_subscription, invite: Fabricate(:invite))
    user = Fabricate(:user, invite: invite)

    expect(subscription.reload.user).to be_nil
  end

  it 'associates a subscription when there is an invite associated with a subscription' do
    invite = Fabricate(:invite)
    subscription = Fabricate(:stripe_subscription, invite: invite)
    user = Fabricate(:user, invite: invite)

    expect(subscription.reload.user).to eq(user)
  end

  it 'creates a membership in the subscription when there is an invite associated with an already-associated subscription' do
    invite = Fabricate(:invite)
    owner = Fabricate(:user, invite: invite)
    subscription = Fabricate(:stripe_subscription, invite: invite, user_id: owner.id)
    user = Fabricate(:user, invite: invite)

    expect(subscription.reload.user).to eq(owner)
    expect(subscription.members.count).to eq(1)
  end

  it 'does not associate a subscription when there is an invite associated with a subscription \
   but the subscription already has a user' do
    invite = Fabricate(:invite)
    subscription = Fabricate(:stripe_subscription, invite: invite, user_id: Fabricate(:user).id)
    user = Fabricate(:user, invite: invite)

    expect(subscription.reload.user).to_not eq(user)
  end

  it 'posts a receipt to RevenueCat when a subscription is associated with the redeemed invite' do
    invite = Fabricate(:invite)
    subscription = Fabricate(:stripe_subscription, invite: invite)
    user = Fabricate(:user, invite: invite)

    expect(WebMock).to have_requested(:post, 'https://api.revenuecat.com/v1/receipts')
  end
end
