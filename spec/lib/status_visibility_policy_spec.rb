# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StatusVisibilityPolicy do
  describe '.restrictions_enabled?' do
    context 'in test environment' do
      it 'returns false when setting is false' do
        Setting.restrict_public_statuses = false
        expect(described_class.restrictions_enabled?).to be false
      end
      
      it 'returns true when setting is true' do
        Setting.restrict_public_statuses = true
        expect(described_class.restrictions_enabled?).to be true
      end
    end
  end
  
  describe '.can_create_visibility?' do
    let(:owner_user) { Fabricate(:owner_user) }
    let(:regular_user) { Fabricate(:user) }
    
    context 'when restrictions are disabled' do
      before { Setting.restrict_public_statuses = false }
      
      it 'allows any account to create public statuses' do
        expect(described_class.can_create_visibility?(regular_user.account, 'public')).to be true
      end
      
      it 'allows any account to create unlisted statuses' do  
        expect(described_class.can_create_visibility?(regular_user.account, 'unlisted')).to be true
      end
    end
    
    context 'when restrictions are enabled' do
      before { Setting.restrict_public_statuses = true }
      
      it 'allows Owner role to create public statuses' do
        expect(described_class.can_create_visibility?(owner_user.account, 'public')).to be true
      end
      
      it 'denies regular users to create public statuses' do
        expect(described_class.can_create_visibility?(regular_user.account, 'public')).to be false
      end
      
      it 'allows all accounts to create private statuses' do
        expect(described_class.can_create_visibility?(regular_user.account, 'private')).to be true
        expect(described_class.can_create_visibility?(owner_user.account, 'private')).to be true
      end
      
      it 'allows all accounts to create direct statuses' do
        expect(described_class.can_create_visibility?(regular_user.account, 'direct')).to be true
      end
    end
  end
  
  describe '.allowed_visibilities_for' do
    let(:owner_user) { Fabricate(:owner_user) }
    let(:regular_user) { Fabricate(:user) }
    
    context 'when restrictions are disabled' do
      before { Setting.restrict_public_statuses = false }
      
      it 'returns all visibilities for any user' do
        expected = %w[private direct limited public unlisted]
        expect(described_class.allowed_visibilities_for(regular_user.account)).to match_array(expected)
      end
    end
    
    context 'when restrictions are enabled' do
      before { Setting.restrict_public_statuses = true }
      
      it 'returns all visibilities for owner' do
        expected = %w[private direct limited public unlisted]
        expect(described_class.allowed_visibilities_for(owner_user.account)).to match_array(expected)
      end
      
      it 'returns limited visibilities for regular user' do
        expected = %w[private direct limited]
        expect(described_class.allowed_visibilities_for(regular_user.account)).to match_array(expected)
      end
    end
  end
  
  describe '.validate_visibility_for_account' do
    let(:owner_user) { Fabricate(:owner_user) }
    let(:regular_user) { Fabricate(:user) }
    
    context 'when restrictions are enabled' do
      before { Setting.restrict_public_statuses = true }
      
      it 'adds error for regular user trying to create public status' do
        status = Status.new(account: regular_user.account, visibility: 'public')
        described_class.validate_visibility_for_account(status)
        
        expect(status.errors[:visibility]).to be_present
        expect(status.errors[:visibility].first).to include('Owner')
      end
      
      it 'does not add error for owner creating public status' do
        status = Status.new(account: owner_user.account, visibility: 'public')
        described_class.validate_visibility_for_account(status)
        
        expect(status.errors[:visibility]).to be_empty
      end
      
      it 'does not add error for private status' do
        status = Status.new(account: regular_user.account, visibility: 'private')
        described_class.validate_visibility_for_account(status)
        
        expect(status.errors[:visibility]).to be_empty
      end
    end
  end
end