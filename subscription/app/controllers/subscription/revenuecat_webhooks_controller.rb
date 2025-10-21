# frozen_string_literal: true

module Subscription
  class RevenuecatWebhooksController < Subscription::ApplicationController
    protect_from_forgery with: :null_session

    def receive
      verify_signature!

      Subscription::RevenuecatWebhookWorker.perform_async(webhook_params.to_json)

      render body: nil, layout: false, status: 201
    rescue Subscription::WebhookVerifier::InvalidSignature => e
      Rails.logger.error("RevenueCat webhook signature verification failed: #{e.message}")
      head 401
    end

    private

    def verify_signature!
      Subscription::WebhookVerifier.verify_revenuecat!(
        request.body.read,
        request.headers['Authorization']
      )
      request.body.rewind
    end

    def webhook_params
      params.permit!.to_h
    end
  end
end
