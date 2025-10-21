# frozen_string_literal: true

module Subscription
  class RevenuecatSubscription < ApplicationRecord
    belongs_to :user, optional: true
    belongs_to :invite, optional: true
    has_many :members, class_name: 'Subscription::SubscriptionMember', foreign_key: 'subscription_id', inverse_of: :subscription, dependent: :destroy

    validates :revenuecat_customer_id, presence: true
    validates :status, presence: true
    validates :subscription_id, uniqueness: true, allow_nil: true

    scope :active, -> { where(status: ['active', 'trialing']).where('expires_at > ? OR expires_at IS NULL', Time.current) }

    def active?
      ['active', 'trialing'].include?(status) && (expires_at.nil? || expires_at > Time.current)
    end

    def trialing?
      status == 'trialing'
    end

    def description
      config = Subscription.revenuecat_products[product_id]
      config ? config['name'] : product_id
    end

    def size
      quantity || 1
    end

    def provider
      case store
      when 'app_store'
        'App Store'
      when 'play_store'
        'Google Play'
      else
        store&.titleize || 'RevenueCat'
      end
    end
  end
end
