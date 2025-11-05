# frozen_string_literal: true

module StatusVisibilityHelpers
  # Creates a status that would be allowed under the current visibility policy
  def create_status_with_visibility(visibility, account: nil, **options)
    account ||= case visibility.to_s
                when 'public', 'unlisted'
                  # In test mode, restrictions are disabled, so any account works
                  # In production mode, this would need an Owner account
                  if StatusVisibilityPolicy.restrictions_enabled?
                    Fabricate(:owner_user).account
                  else
                    Fabricate(:account)
                  end
                else
                  Fabricate(:account)
                end
    
    Fabricate(:status, account: account, visibility: visibility, **options)
  end
  
  # Creates a public status (with proper permissions)
  def create_public_status(**options)
    create_status_with_visibility(:public, **options)
  end
  
  # Creates an unlisted status (with proper permissions) 
  def create_unlisted_status(**options)
    create_status_with_visibility(:unlisted, **options)
  end
  
  # Temporarily disable visibility restrictions for a block
  def without_visibility_restrictions(&block)
    return yield unless StatusVisibilityPolicy.restrictions_enabled?
    
    original_setting = Setting.restrict_public_statuses
    Setting.restrict_public_statuses = false
    
    begin
      yield
    ensure
      Setting.restrict_public_statuses = original_setting
    end
  end
  
  # Temporarily enable visibility restrictions for a block (useful in test env)
  def with_visibility_restrictions(&block)
    original_setting = Setting.restrict_public_statuses
    Setting.restrict_public_statuses = true
    
    begin
      yield
    ensure
      Setting.restrict_public_statuses = original_setting
    end
  end
end

RSpec.configure do |config|
  config.include StatusVisibilityHelpers
end