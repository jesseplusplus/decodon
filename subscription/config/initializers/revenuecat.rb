# frozen_string_literal: true

module Subscription
  def self.revenuecat_products
    @revenuecat_products ||= begin
      config_file = File.join(File.dirname(__FILE__), '..', 'revenuecat_products.yml')
      config = YAML.load_file(config_file)
      env = Rails.env.to_s
      config[env]['products']
    end
  end

  def self.revenuecat_webhook_secret
    ENV.fetch('REVENUECAT_WEBHOOK_SECRET', nil)
  end
end
