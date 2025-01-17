module Subscription
  class SubscriptionsController < ::Settings::BaseController
    before_action :set_user
    before_action :set_prices, except: [:join]
    skip_before_action :require_functional!

    def index
      @subscriptions = StripeSubscription.all.where(user_id: current_account.user.id)
      if (@subscriptions.empty?)
        @subscriptions = SubscriptionMember.all.where(user_id: current_account.user.id).map(&:subscription)
      end
      @data = @subscriptions.each_with_object({}) do |sub, hash|
          url = ::Stripe::BillingPortal::Session.create({
            customer: sub.customer_id,
          }).url

          hash[sub.id] = {
            url: url,
            owner: sub.user_id == @user.id,
          }
      end
      single_price = ::Stripe::Price.retrieve(@prices[:single])
      group_price = ::Stripe::Price.retrieve(@prices[:group])
      @single_plan = ::Stripe::Product.retrieve(single_price[:product]).name
      @group_plan = ::Stripe::Product.retrieve(group_price[:product]).name
    end

    def create
      single = [{
        price: @prices[:single],
        quantity: 1,
      }]
      group = [{
        price: @prices[:group],
        quantity: params[:quantity].to_i || 1,
        adjustable_quantity: {
          enabled: true,
          minimum: 1,
        },
      }]
      items = params[:quantity] ? group : single
      session = ::Stripe::Checkout::Session.create({
        line_items: items,
        mode: 'subscription',
        client_reference_id: @user.id,
        allow_promotion_codes: true,
        success_url: settings_subscription.subscriptions_url,
      })

      redirect_to session.url, status: 303
    end
  
    def join
      if (params[:invite].nil?)
        redirect_to settings_subscription.subscriptions_url, flash: { error: "Please enter a valid invite" }
      end
      code = params[:invite].split('/').last.strip
      invite = ::Invite.find_by(code: code)
      if (invite.nil?)
        redirect_to settings_subscription.subscriptions_url, flash: { error: "Invite not found" }
      elsif (invite.uses <= invite.max_uses)
        sub = Subscription::StripeSubscription.find_by(invite_id: invite.id)
        sub.members.create(user_id: @user.id)
        @user.invite = invite
        @user.save!
        render settings_subscription.subscriptions_url, status: 200
      else
        redirect_to settings_subscription.subscriptions_url, flash: { error: "Invite is not valid for any more uses" }
      end
    end
  
    private
    def set_user
      @user = current_account.user
    end

    def set_prices
      @prices = {
        single: ENV['STRIPE_PRICE_1'],
        group: ENV['STRIPE_PRICE_2'],
      }
    end
  end
end