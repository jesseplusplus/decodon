# frozen_string_literal: true

require 'rails_helper'

RSpec.describe List do
  describe 'Validations' do
    subject { Fabricate.build :list }

    it { is_expected.to validate_presence_of(:title) }

    context 'when account has hit max list limit' do
      let(:account) { Fabricate :account }

      before do
        stub_const 'List::PER_ACCOUNT_LIMIT', 3

        Fabricate(:list, account: account)
      end

      context 'when creating a new list' do
        it { is_expected.to_not allow_value(account).for(:account).against(:base).with_message(I18n.t('lists.errors.limit')) }
      end

      context 'when updating an existing list' do
        before { subject.save(validate: false) }

        it { is_expected.to allow_value(account).for(:account).against(:base) }
      end
    end

    context 'when trying to rename Favorites list' do
      let(:account) { Fabricate :account }

      # rubocop:disable RSpec/LeadingSubject
      subject { account.owned_lists.find_by(title: 'Favorites') }
      # rubocop:enable RSpec/LeadingSubject

      it { is_expected.to_not allow_value('New title').for(:title).against(:base) }
    end

    context 'when trying to rename a list' do
      let(:account) { Fabricate :account }
      let(:favorites) { account.owned_lists.find_by(title: 'Favorites') }

      it { is_expected.to allow_value('New title').for(:title).against(:base) }

      it 'does not allow creating a new list with a duplicate name' do
        new_list = Fabricate.build(:list, account: account, title: 'Favorites')
        expect(new_list).to_not be_valid
        expect(new_list.errors[:title]).to include(I18n.t('errors.messages.taken'))
      end
    end
  end
end
