# frozen_string_literal: true

module Subscription
  class SubscriptionsController < ::Settings::BaseController
    before_action :set_user
    before_action :set_prices, except: [:join]
    skip_before_action :require_functional!

    def index
      stripe_subscriptions = StripeSubscription.where(user_id: current_account.user.id)
      revenuecat_subscriptions = RevenuecatSubscription.where(user_id: current_account.user.id)

      @subscriptions = (stripe_subscriptions + revenuecat_subscriptions)

      @subscriptions = SubscriptionMember.where(user_id: current_account.user.id).includes(:subscription).map(&:subscription) if @subscriptions.empty?

      @data = @subscriptions.each_with_object({}) do |sub, hash|
        url = if sub.is_a?(StripeSubscription)
                ::Stripe::BillingPortal::Session.create({
                  customer: sub.customer_id,
                }).url
              elsif sub.is_a?(RevenuecatSubscription)
                case sub.store
                when 'app_store'
                  'https://apps.apple.com/account/subscriptions'
                when 'play_store'
                  'https://play.google.com/store/account/subscriptions'
                end
              end

        hash[sub.id] = {
          url: url,
          owner: sub.user_id == @user.id,
          provider: sub.is_a?(StripeSubscription) ? 'Stripe' : sub.provider,
          status: sub.status,
          expires_at: sub.expires_at,
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
        quantity: params[:quantity].to_i,
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
      redirect_to settings_subscription.subscriptions_url, flash: { error: 'Please enter a valid invite' } if params[:invite].nil?

      code = params[:invite].split('/').last.strip
      invite = ::Invite.find_by(code: code)
      if invite.nil?
        redirect_to settings_subscription.subscriptions_url, flash: { error: 'Invite not found' }
      elsif invite.uses <= invite.max_uses
        sub = Subscription::StripeSubscription.find_by(invite_id: invite.id) ||
              Subscription::RevenuecatSubscription.find_by(invite_id: invite.id)

        if sub.present?
          sub.members.create(user_id: @user.id)
          @user.invite = invite
          @user.save!
          render settings_subscription.subscriptions_url, status: 200
        else
          redirect_to settings_subscription.subscriptions_url, flash: { error: 'Subscription not found' }
        end
      else
        redirect_to settings_subscription.subscriptions_url, flash: { error: 'Invite is not valid for any more uses' }
      end
    end

    private

    def set_user
      @user = current_account.user
    end

    def set_prices
      @prices = {
        single: ENV.fetch('STRIPE_PRICE_1', nil),
        group: ENV.fetch('STRIPE_PRICE_2', nil),
      }
    end
  end
end
