# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ActivityPub Contexts' do
  let!(:status) { Fabricate(:status) }
  let(:conversation) { status.conversation }

  describe 'GET #show' do
    subject { get context_path(id: conversation.parent_status_id), headers: nil }

    let!(:unrelated_status) { Fabricate(:status) }

    it 'returns http success and correct media type and correct items' do
      subject

      expect(response)
        .to have_http_status(200)
        .and have_cacheable_headers

      expect(response.media_type)
        .to eq 'application/activity+json'

      expect(response.parsed_body[:type])
        .to eq 'Collection'

      expect(response.parsed_body[:first][:items])
        .to be_an(Array)
        .and have_attributes(size: 1)
        .and include(ActivityPub::TagManager.instance.uri_for(status))
        .and not_include(ActivityPub::TagManager.instance.uri_for(unrelated_status))
    end

    context 'with pagination' do
      context 'with few statuses' do
        before do
          3.times do
            Fabricate(:status, conversation: conversation)
          end
        end

        it 'does not include a next page link' do
          subject

          expect(response.parsed_body[:first][:next]).to be_nil
        end
      end

      context 'with many statuses' do
        before do
          (ActivityPub::ContextsController::DESCENDANTS_LIMIT + 1).times do
            Fabricate(:status, conversation: conversation)
          end
        end

        it 'includes a next page link' do
          subject

          expect(response.parsed_body['first']['next']).to_not be_nil
        end
      end
    end
  end

  describe 'GET #items' do
    subject { get items_context_path(id: conversation.parent_status_id, page: 0, min_id: nil), headers: nil }

    context 'with few statuses' do
      before do
        2.times do
          Fabricate(:status, conversation: conversation)
        end
      end

      it 'returns http success and correct media type and correct items' do
        subject

        expect(response)
          .to have_http_status(200)

        expect(response.media_type)
          .to eq 'application/activity+json'

        expect(response.parsed_body[:type])
          .to eq 'Collection'

        expect(response.parsed_body[:first][:items])
          .to be_an(Array)
          .and have_attributes(size: 3)

        expect(response.parsed_body[:first][:next]).to be_nil
      end
    end

    context 'with many statuses' do
      before do
        (ActivityPub::ContextsController::DESCENDANTS_LIMIT + 1).times do
          Fabricate(:status, conversation: conversation)
        end
      end

      it 'includes a next page link' do
        subject

        expect(response.parsed_body['first']['next']).to_not be_nil
      end
    end

    context 'with page requested' do
      before do
        ActivityPub::ContextsController::DESCENDANTS_LIMIT.times do |_i|
          Fabricate(:status, conversation_id: conversation.id)
        end
      end

      it 'returns the correct items' do
        get items_context_path(id: conversation.parent_status_id, page: 0, min_id: nil), headers: nil
        next_page = response.parsed_body['first']['next']
        get next_page, headers: nil

        expect(response.parsed_body['items'])
          .to be_an(Array)
          .and have_attributes(size: 1)
      end
    end
  end
end
