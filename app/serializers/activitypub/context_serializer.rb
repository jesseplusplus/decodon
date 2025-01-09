# frozen_string_literal: true

class ActivityPub::ContextSerializer < ActivityPub::Serializer
  include RoutingHelper

  attributes :id, :type

  def id
    ActivityPub::TagManager.instance.uri_for(object)
  end

  def type
    'Collection'
  end
end
