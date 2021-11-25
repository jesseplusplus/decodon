# frozen_string_literal: true

class Admin::Metrics::Dimension::BaseDimension
  def self.with_params?
    false
  end

  def initialize(start_at, end_at, limit, params)
    @start_at = start_at&.to_datetime
    @end_at   = end_at&.to_datetime
    @limit    = limit&.to_i
    @params   = params
  end

  def key
    raise NotImplementedError
  end

  def cache_key
    ["metrics/dimension/#{key}", @start_at, @end_at, @limit, canonicalized_params].join(';')
  end

  def data
    load
  end

  def self.model_name
    self.class.name
  end

  def read_attribute_for_serialization(key)
    send(key) if respond_to?(key)
  end

  protected

  def load
    unless loaded?
      @values = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { perform_query }
      @loaded = true
    end

    @values
  end

  def perform_query
    raise NotImplementedError
  end

  def time_period
    (@start_at..@end_at)
  end

  def params
    raise NotImplementedError
  end
end
