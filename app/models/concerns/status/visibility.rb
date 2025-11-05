# frozen_string_literal: true

module Status::Visibility
  extend ActiveSupport::Concern

  included do
    enum :visibility,
         { public: 0, unlisted: 1, private: 2, direct: 3, limited: 4 },
         suffix: :visibility,
         validate: true

    scope :distributable_visibility, -> { where(visibility: %i(public unlisted)) }
    scope :list_eligible_visibility, -> { where(visibility: %i(public unlisted private)) }
    scope :not_direct_visibility, -> { where.not(visibility: :direct) }

    validates :visibility, exclusion: { in: %w(direct limited) }, if: :reblog?
    validate :validate_visibility_restrictions

    before_validation :set_visibility, unless: :visibility?
  end

  class_methods do
    def selectable_visibilities
      visibilities.keys - %w(direct limited)
    end
    
    def selectable_visibilities_for(account)
      StatusVisibilityPolicy.allowed_visibilities_for(account)
    end
  end

  def hidden?
    !distributable?
  end

  def distributable?
    public_visibility? || unlisted_visibility?
  end

  def sign?
    distributable? || limited_visibility?
  end

  private

  def set_visibility
    self.visibility ||= reblog.visibility if reblog?
    self.visibility ||= visibility_from_account
  end

  def visibility_from_account
    if account.locked?
      :private
    elsif StatusVisibilityPolicy.can_create_visibility?(account, 'public')
      :public
    else
      :private  # Default to private if public visibility is restricted
    end
  end
  
  def validate_visibility_restrictions
    return unless account&.local?
    
    StatusVisibilityPolicy.validate_visibility_for_account(self)
  end
end
