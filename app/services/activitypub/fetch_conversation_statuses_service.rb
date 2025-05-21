# frozen_string_literal: true

class ActivityPub::FetchConversationStatusesService < BaseService
  include JsonLdHelper

  def call(parent_status, collection_or_uri, allow_synchronous_requests: true, request_id: nil)
    @parent_status = parent_status
    @account = @parent_status.account
    @allow_synchronous_requests = allow_synchronous_requests
    @request_id = request_id

    process_collection(collection_or_uri)
  end

  private

  def process_collection(collection_or_uri)
    collection = fetch_collection(collection_or_uri)
    return unless collection.is_a?(Hash)

    if collection['first'].present?
      process_collection(collection['first'])

      ActivityPub::FetchConversationStatusesWorker.perform_in(rand(30..60).seconds, @parent_status.id, collection['next'], { 'request_id' => @request_id }) if collection['next'].present?
    else
      items = case collection['type']
              when 'Collection', 'CollectionPage'
                as_array(collection['items'])
              when 'OrderedCollection', 'OrderedCollectionPage'
                as_array(collection['orderedItems'])
              end

      return if items.nil?

      items.each_slice(10) do |chunk|
        ActivityPub::FetchConversationStatusesWorker.push_bulk(chunk) do |item|
          [@parent_status.id, value_or_id(item), { request_id: @request_id }]
        end
      end
    end
  end

  def fetch_collection(collection_or_uri)
    return collection_or_uri if collection_or_uri.is_a?(Hash)
    return unless @allow_synchronous_requests

    # NOTE: For backward compatibility reasons, Mastodon signs outgoing
    # queries incorrectly by default.
    #
    # Therefore, retry with correct signatures if this fails.
    begin
      fetch_resource_without_id_validation(collection_or_uri, nil, true)
    rescue Mastodon::UnexpectedResponseError => e
      raise unless e.response && e.response.code == 401 && Addressable::URI.parse(collection_or_uri).query.present?

      fetch_resource_without_id_validation(collection_or_uri, nil, true, request_options: { omit_query_string: false })
    end
  end
end
