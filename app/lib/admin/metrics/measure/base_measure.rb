# frozen_string_literal: true

class Admin::Metrics::Measure::BaseMeasure
  def self.with_params?
    false
  end

  def initialize(start_at, end_at, params)
    @start_at = start_at&.to_datetime
    @end_at   = end_at&.to_datetime
    @params   = params
  end

  def key
    raise NotImplementedError
  end

  def unit
    nil
  end

  def total_in_time_range?
    true
  end

  def total
    load[:total]
  end

  def previous_total
    load[:previous_total]
  end

  def data
    load[:data]
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
      @values = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { perform_queries }.with_indifferent_access
      @loaded = true
    end

    @values
  end

  def perform_queries
    {
      total: perform_total_query,
      previous_total: perform_previous_total_query,
      data: perform_data_query,
    }
  end

  def perform_total_query
    raise NotImplementedError
  end

  def perform_previous_total_query
    raise NotImplementedError
  end

  def perform_data_query
    raise NotImplementedError
  end

  def time_period
    (@start_at..@end_at)
  end

  def previous_time_period
    ((@start_at - length_of_period)..(@end_at - length_of_period))
  end

  def length_of_period
    @length_of_period ||= @end_at - @start_at
  end

  def params
    raise NotImplementedError
  end
end
