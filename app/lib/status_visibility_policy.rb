# frozen_string_literal: true

class StatusVisibilityPolicy
  # Check if a user account can create statuses with the given visibility level
  def self.can_create_visibility?(account, visibility)
    return true unless restrictions_enabled?
    return true if visibility.in?(%w[private direct limited]) # Always allow private visibilities
    
    # For public/unlisted visibility, check if user has required role
    return true if account.nil? || account.user.nil? # Allow for system/remote accounts
    
    allowed_roles = Setting.public_status_allowed_roles || ['Owner']
    user_role_name = account.user.role&.name
    
    allowed_roles.include?(user_role_name)
  end
  
  # Check if the visibility restriction feature is enabled
  def self.restrictions_enabled?
    # In test environment, respect the configuration setting
    # In other environments, default to enabled if not explicitly set
    if Rails.env.test?
      Setting.restrict_public_statuses
    else
      Setting.restrict_public_statuses != false
    end
  end
  
  # Get list of allowed visibilities for an account
  def self.allowed_visibilities_for(account)
    base_visibilities = %w[private direct limited]
    
    if can_create_visibility?(account, 'public')
      base_visibilities + %w[public unlisted]
    else
      base_visibilities
    end
  end
  
  # Validation method that can be used in models
  def self.validate_visibility_for_account(record)
    return if record.account.nil?
    return if can_create_visibility?(record.account, record.visibility)
    
    allowed_roles = Setting.public_status_allowed_roles || ['Owner']
    role_names = allowed_roles.join(', ')
    
    record.errors.add(
      :visibility, 
      "Public and unlisted visibilities are restricted to accounts with roles: #{role_names}"
    )
  end
end