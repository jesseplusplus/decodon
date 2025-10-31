# frozen_string_literal: true

# This migration comes from subscription (originally 20251020000001)
class CreateSubscriptionRevenuecatSubscriptions < ActiveRecord::Migration[6.1]
  def change
    create_table :subscription_revenuecat_subscriptions do |t|
      t.bigint :user_id
      t.bigint :invite_id
      t.string :revenuecat_customer_id, null: false
      t.string :subscription_id
      t.string :product_id
      t.string :store
      t.string :status
      t.datetime :expires_at
      t.datetime :trial_ends_at
      t.integer :quantity, default: 1
      t.string :environment

      t.timestamps
    end

    add_index :subscription_revenuecat_subscriptions, :revenuecat_customer_id, name: 'index_revenuecat_subs_on_customer_id'
    add_index :subscription_revenuecat_subscriptions, :subscription_id, name: 'index_revenuecat_subs_on_subscription_id'
  end
end
