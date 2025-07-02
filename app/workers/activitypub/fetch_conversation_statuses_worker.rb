# frozen_string_literal: true

class ActivityPub::FetchConversationStatusesWorker
  include Sidekiq::Worker
  include JsonLdHelper

  sidekiq_options queue: 'pull', retry: 2

  def perform(parent_status_id, uri, options = {})
    parent_status = Status.find(parent_status_id)

    begin
      resource = fetch_resource_without_id_validation(uri, nil, true)
      if resource.is_a?(Hash) && %w(Collection CollectionPage OrderedCollection OrderedCollectionPage).include?(resource['type'])
        ActivityPub::FetchConversationStatusesService.new.call(parent_status, uri, **options.deep_symbolize_keys)
      else
        ActivityPub::FetchRemoteStatusService.new.call(uri, conversation: parent_status.conversation, **options.deep_symbolize_keys)
      end
    rescue Mastodon::UnexpectedResponseError, HTTP::Error, OpenSSL::SSL::SSLError => e
      Rails.logger.warn "Error fetching resource #{uri}: #{e}"
      # If we can't fetch the resource, assume it's a status to maintain backward compatibility
      ActivityPub::FetchRemoteStatusService.new.call(uri, conversation: parent_status.conversation, **options.deep_symbolize_keys)
    end
  end
end
