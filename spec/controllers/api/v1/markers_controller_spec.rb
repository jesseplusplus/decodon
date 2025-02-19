# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::MarkersController do
  let(:user)  { Fabricate(:user) }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: 'write:statuses') }

  before do
    allow(controller).to receive(:doorkeeper_token) { token }
  end

  describe 'POST #create' do
    it 'creates markers for account-based timelines' do
      post :create, params: {
        'account:123': { last_read_id: '456' },
      }

      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json['account:123']).to include('last_read_id' => '456')
    end
  end
end
