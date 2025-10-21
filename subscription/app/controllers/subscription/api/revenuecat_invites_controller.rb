# frozen_string_literal: true

module Subscription
  class Api::RevenuecatInvitesController < ::Api::BaseController
    skip_before_action :require_authenticated_user!
    skip_before_action :require_not_suspended!

    def show
      customer_id = params[:revenuecat_customer_id]

      subscription = Subscription::RevenuecatSubscription.find_by(
        revenuecat_customer_id: customer_id
      )

      return render json: { status: 'processing' }, status: 202 if subscription.nil?

      unless subscription.active?
        return render json: {
          error: 'Subscription not active',
          status: subscription.status,
        }, status: 422
      end

      invite = subscription.invite
      if invite.nil?
        return render json: {
          error: 'No invite associated with subscription',
        }, status: 404
      end

      if invite.uses >= invite.max_uses
        return render json: {
          error: 'Invite code has been fully used',
          invite_code: invite.code,
        }, status: 422
      end

      render json: {
        invite_code: invite.code,
        status: subscription.status,
        expires_at: subscription.expires_at,
        trial_ends_at: subscription.trial_ends_at,
        provider: subscription.provider,
        product: subscription.description,
      }, status: 200
    end
  end
end
