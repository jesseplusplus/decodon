# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::ContextsController do
  let(:user) { Fabricate(:user) }
  let(:conversation) { Fabricate(:conversation) }

  before do
    allow(controller).to receive(:signed_request_actor).and_return(nil)
  end

  describe 'GET #show' do
    context 'with few statuses' do
      before do
        3.times do
          Fabricate(:status, visibility: :private, account: user.account, conversation: conversation)
        end
      end

      it 'does not include a next page link' do
        get :show, params: { id: conversation.id }
        json = JSON.parse(response.body)
        expect(json['first']['next']).to be_nil
      end
    end

    context 'with many statuses' do
      before do
        (ActivityPub::ContextsController::DESCENDANTS_LIMIT + 1).times do
          Fabricate(:status, visibility: :private, account: user.account, conversation: conversation)
        end
      end

      it 'includes a next page link' do
        get :show, params: { id: conversation.id }
        json = JSON.parse(response.body)
        expect(json['first']['next']).to_not be_nil
      end
    end
  end
end
