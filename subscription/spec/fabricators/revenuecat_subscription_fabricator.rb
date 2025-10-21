# frozen_string_literal: true

Fabricator(:revenuecat_subscription, class_name: 'Subscription::RevenuecatSubscription') do
  revenuecat_customer_id { SecureRandom.uuid }
  subscription_id { "rc_sub_#{SecureRandom.hex(8)}" }
  product_id { 'rc_monthly_individual' }
  store { 'app_store' }
  status { 'active' }
  expires_at { 1.month.from_now }
  quantity { 1 }
  environment { 'production' }
end
