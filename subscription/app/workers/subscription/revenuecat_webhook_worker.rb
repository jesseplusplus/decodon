# frozen_string_literal: true

module Subscription
  class RevenuecatWebhookWorker
    include Sidekiq::Worker

    sidekiq_options queue: 'default'

    def perform(event_json)
      event_payload = JSON.parse(event_json)
      event = event_payload['event']
      event_type = event['type']

      return if stripe_event?(event)

      case event_type
      when 'INITIAL_PURCHASE'
        handle_initial_purchase(event)
      when 'RENEWAL'
        handle_renewal(event)
      when 'CANCELLATION'
        handle_cancellation(event)
      when 'EXPIRATION'
        handle_expiration(event)
      when 'UNCANCELLATION'
        handle_uncancellation(event)
      when 'BILLING_ISSUES'
        handle_billing_issue(event)
      when 'PRODUCT_CHANGE'
        handle_product_change(event)
      when 'TRANSFER'
        handle_transfer(event)
      else
        Rails.logger.info("Unhandled RevenueCat event type: #{event_type}")
      end
    rescue => e
      Rails.logger.error("RevenueCat webhook processing error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    end

    private

    def stripe_event?(event)
      store = event['store']
      store == 'STRIPE'
    end

    def handle_initial_purchase(event)
      data = extract_subscription_data(event)

      subscription = RevenuecatSubscription.find_by(
        revenuecat_customer_id: data[:revenuecat_customer_id],
        subscription_id: data[:subscription_id]
      )

      return if subscription.present?

      product_config = Subscription.revenuecat_products[data[:product_id]]
      max_uses = product_config ? product_config['max_uses'] : 1

      instance_user = InstancePresenter.new.contact.account&.user

      invite = Invite.create!(
        user_id: instance_user&.id,
        max_uses: max_uses
      )

      RevenuecatSubscription.create!(
        revenuecat_customer_id: data[:revenuecat_customer_id],
        subscription_id: data[:subscription_id],
        product_id: data[:product_id],
        store: data[:store],
        status: data[:status],
        expires_at: data[:expires_at],
        trial_ends_at: data[:trial_ends_at],
        quantity: data[:quantity],
        environment: data[:environment],
        invite_id: invite.id
      )

      Rails.logger.info("Created RevenueCat subscription #{data[:subscription_id]} with invite #{invite.code}")
    end

    def handle_renewal(event)
      data = extract_subscription_data(event)
      subscription = find_subscription(data[:subscription_id])

      if subscription.present?
        subscription.update!(
          expires_at: data[:expires_at],
          status: data[:status],
          trial_ends_at: data[:trial_ends_at]
        )
      else
        RevenuecatSubscription.create!(
          revenuecat_customer_id: data[:revenuecat_customer_id],
          subscription_id: data[:subscription_id],
          product_id: data[:product_id],
          store: data[:store],
          status: data[:status],
          expires_at: data[:expires_at]
        )
      end

      Rails.logger.info("Renewed subscription #{data[:subscription_id]}")
    end

    def handle_cancellation(event)
      data = extract_subscription_data(event)
      subscription = find_subscription(data[:subscription_id])

      return unless subscription

      subscription.update!(status: 'canceled')

      Rails.logger.info("Canceled subscription #{data[:subscription_id]}")
    end

    def handle_expiration(event)
      data = extract_subscription_data(event)
      subscription = find_subscription(data[:subscription_id])

      return unless subscription

      subscription.update!(status: data[:status])

      Rails.logger.info("Expired subscription #{data[:subscription_id]}")
    end

    def handle_uncancellation(event)
      data = extract_subscription_data(event)
      subscription = find_subscription(data[:subscription_id])

      return unless subscription

      subscription.update!(
        status: data[:status],
        expires_at: data[:expires_at]
      )

      Rails.logger.info("Uncanceled subscription #{data[:subscription_id]}")
    end

    def handle_billing_issue(event)
      data = extract_subscription_data(event)
      subscription = find_subscription(data[:subscription_id])

      return unless subscription

      subscription.update!(status: data[:status])

      Rails.logger.info("Billing issue for subscription #{data[:subscription_id]}")
    end

    def handle_product_change(event)
      data = extract_subscription_data(event)
      subscription = find_subscription(data[:subscription_id])

      return unless subscription

      subscription.update!(
        product_id: data[:product_id]
      )

      Rails.logger.info("Changed product for subscription #{data[:subscription_id]} to #{data[:product_id]}")
    end

    def handle_transfer(event)
      transferred_from = event['transferred_from']
      transferred_to = event['transferred_to']

      return unless transferred_from.present? && transferred_to.present?

      Array(transferred_from).each do |old_customer_id|
        subscription = RevenuecatSubscription.find_by(revenuecat_customer_id: old_customer_id)

        next if subscription.blank?

        new_customer_id = Array(transferred_to).first
        user = User.find_by(id: new_customer_id)

        next if user.blank?

        subscription.update!(
          user_id: user.id
        )

        Rails.logger.info("Transferred subscription #{subscription.subscription_id} from #{old_customer_id} to user #{user.id}")
      end
    end

    def extract_subscription_data(event)
      original_app_user_id = event['original_app_user_id']
      app_user_id = event['app_user_id']
      product_id = event['product_id']
      store = event['store']
      environment = event['environment']
      period_type = event['period_type']

      original_transaction_id = event['original_transaction_id']

      expires_at = parse_timestamp_ms(event['expiration_at_ms'])

      trial_ends_at = nil
      trial_ends_at = expires_at if period_type == 'TRIAL'

      status = determine_status(event)

      {
        revenuecat_customer_id: original_app_user_id,
        app_user_id: app_user_id,
        subscription_id: original_transaction_id,
        product_id: product_id,
        store: store&.downcase,
        status: status,
        expires_at: expires_at,
        trial_ends_at: trial_ends_at,
        quantity: 1,
        environment: environment&.downcase || 'production',
      }
    end

    def determine_status(event)
      period_type = event['period_type']
      cancellation_at = event['cancel_at_ms']
      expiration_at = event['expiration_at_ms']

      return 'expired' if expiration_at.present? && expiration_at < (Time.current.to_f * 1000)

      return 'canceled' if cancellation_at.present?

      case period_type
      when 'TRIAL'
        'trialing'
      when 'INTRO', 'NORMAL'
        'active'
      end
    end

    def parse_timestamp_ms(timestamp_ms)
      return nil if timestamp_ms.blank?

      Time.zone.at(timestamp_ms / 1000.0)
    rescue ArgumentError
      nil
    end

    def find_subscription(subscription_id)
      RevenuecatSubscription.find_by(subscription_id: subscription_id)
    end
  end
end
