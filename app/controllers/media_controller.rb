# frozen_string_literal: true

class MediaController < ApplicationController
  include Authorization

  skip_before_action :require_functional!, unless: :limited_federation_mode?

  before_action :authenticate_user!, if: :limited_federation_mode?
  before_action :authenticate_with_bearer_token, if: :bearer_token_present?
  before_action :set_media_attachment
  before_action :verify_permitted_status!
  before_action :check_playable, only: :player
  before_action :allow_iframing, only: :player

  content_security_policy only: :player do |policy|
    policy.frame_ancestors(false)
  end

  def show
    redirect_to @media_attachment.file.url(:original)
  end

  def player; end

  private

  def set_media_attachment
    id = params[:id] || params[:medium_id]
    return if id.nil?

    scope = MediaAttachment.local.attached
    # If id is 19 characters long, it's a shortcode, otherwise it's an identifier
    @media_attachment = id.size == 19 ? scope.find_by!(shortcode: id) : scope.find(id)
  end

  def bearer_token_present?
    request.headers['Authorization']&.start_with?('Bearer ')
  end

  def authenticate_with_bearer_token
    token = request.headers['Authorization']&.split(' ', 2)&.last
    @capability_token = StatusCapabilityToken.find_by(token: token)

    head 401 if @capability_token.nil?
  end

  def verify_permitted_status!
    if @capability_token
      not_found unless @media_attachment.status_id == @capability_token.status_id
    else
      authorize @media_attachment.status, :show?
    end
  rescue Mastodon::NotPermittedError
    not_found
  end

  def check_playable
    not_found unless @media_attachment.larger_media_format?
  end

  def allow_iframing
    response.headers.delete('X-Frame-Options')
  end
end
