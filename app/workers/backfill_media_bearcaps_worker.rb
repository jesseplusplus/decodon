# frozen_string_literal: true

class BackfillMediaBearcapsWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: 3, lock: :until_executed

  BATCH_SIZE = 100
  DELAY_BETWEEN_BATCHES = 5.seconds

  def perform(min_id = nil)
    # Find non-distributable statuses with media attachments that need bearcap URLs
    scope = Status.local
                  .where.not(visibility: %i(public unlisted))
                  .joins(:media_attachments)
                  .distinct
                  .order(id: :asc)

    scope = scope.where('statuses.id > ?', min_id) if min_id.present?

    status_ids = scope.limit(BATCH_SIZE).pluck(:id)

    return if status_ids.empty?

    status_ids.each do |status_id|
      process_status(status_id)
    end

    last_id = status_ids.last
    BackfillMediaBearcapsWorker.perform_in(DELAY_BETWEEN_BATCHES, last_id)
  end

  private

  def process_status(status_id)
    status = Status.find_by(id: status_id)
    return if status.nil?

    status.ensure_capability_token
    status.update_column(:edited_at, Time.now.utc)

    ActivityPub::StatusUpdateDistributionWorker.perform_async(status_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
