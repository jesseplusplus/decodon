# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BackfillMediaBearcapsWorker do
  subject { described_class.new }

  let(:owner_account) { Fabricate(:user, role: UserRole.find_by(name: 'Owner')).account }

  let!(:public_status_with_media) do
    Fabricate(:status, account: owner_account, visibility: :public).tap do |status|
      Fabricate(:media_attachment, account: owner_account, status: status)
    end
  end

  let!(:private_status_with_media) do
    Fabricate(:status, visibility: :private).tap do |status|
      Fabricate(:media_attachment, account: status.account, status: status)
    end
  end

  let!(:unlisted_status_with_media) do
    Fabricate(:status, account: owner_account, visibility: :unlisted).tap do |status|
      Fabricate(:media_attachment, account: owner_account, status: status)
    end
  end

  let!(:direct_status_with_media) do
    Fabricate(:status, visibility: :direct).tap do |status|
      Fabricate(:media_attachment, account: status.account, status: status)
    end
  end

  describe '#perform' do
    context 'without a min_id parameter' do
      it 'processes only private/direct/limited statuses with media attachments' do
        allow(ActivityPub::StatusUpdateDistributionWorker).to receive(:perform_async)
        allow(described_class).to receive(:perform_in)

        subject.perform

        expect(ActivityPub::StatusUpdateDistributionWorker)
          .to have_received(:perform_async).with(private_status_with_media.id)
        expect(ActivityPub::StatusUpdateDistributionWorker)
          .to have_received(:perform_async).with(direct_status_with_media.id)
        expect(ActivityPub::StatusUpdateDistributionWorker)
          .to_not have_received(:perform_async).with(public_status_with_media.id)
        expect(ActivityPub::StatusUpdateDistributionWorker)
          .to_not have_received(:perform_async).with(unlisted_status_with_media.id)

        expect(described_class)
          .to have_received(:perform_in).with(5.seconds, satisfy { |id| [private_status_with_media.id, direct_status_with_media.id].include?(id) })
      end

      it 'ensures capability tokens exist for processed statuses' do
        allow(ActivityPub::StatusUpdateDistributionWorker).to receive(:perform_async)
        allow(described_class).to receive(:perform_in)

        subject.perform

        expect(private_status_with_media.reload.capability_tokens).to exist
        expect(direct_status_with_media.reload.capability_tokens).to exist
      end
    end

    context 'with a min_id parameter' do
      it 'only processes statuses after the given ID' do
        allow(ActivityPub::StatusUpdateDistributionWorker).to receive(:perform_async)
        allow(described_class).to receive(:perform_in)

        subject.perform(private_status_with_media.id)

        expect(ActivityPub::StatusUpdateDistributionWorker)
          .to have_received(:perform_async).with(direct_status_with_media.id)
        expect(ActivityPub::StatusUpdateDistributionWorker)
          .to_not have_received(:perform_async).with(private_status_with_media.id)
      end
    end

    context 'when there are no more statuses to process' do
      it 'does not queue another batch' do
        allow(ActivityPub::StatusUpdateDistributionWorker).to receive(:perform_async)
        allow(described_class).to receive(:perform_in)

        # Process all statuses
        Status.local.where.not(visibility: %i(public unlisted)).joins(:media_attachments).distinct.pluck(:id).max.tap do |max_id|
          subject.perform(max_id)
        end

        expect(described_class)
          .to_not have_received(:perform_in)
      end
    end

    context 'when a status no longer exists' do
      it 'handles the missing record gracefully' do
        non_existent_id = Status.maximum(:id).to_i + 1000

        expect { subject.perform(non_existent_id) }
          .to_not raise_error
      end
    end
  end
end
