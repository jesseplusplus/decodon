# Fork Management Strategy

This document outlines the strategy for maintaining this Mastodon fork while minimizing merge conflicts and ensuring CI compatibility.

## Overview

This fork implements several customizations to Mastodon, particularly around status visibility restrictions. To maintain compatibility with upstream updates while preserving our changes, we use a **Configuration-Driven Approach**.

## Key Changes Made

### 1. Status Visibility Restrictions

Instead of hard-coding role checks in the Status model, we now use:

- **Configuration-based restrictions** via `config/settings.yml`
- **Environment-specific behavior** (test mode allows upstream compatibility)
- **Policy class** (`StatusVisibilityPolicy`) to centralize logic

#### Files Modified:
- `config/settings.yml` - Added fork-specific settings
- `app/lib/status_visibility_policy.rb` - New policy class (CREATED)
- `app/models/concerns/status/visibility.rb` - Replaced hard-coded validation
- `spec/support/status_visibility_helpers.rb` - Test helpers (CREATED)
- `spec/lib/status_visibility_policy_spec.rb` - Policy tests (CREATED)

### 2. Test Environment Compatibility

Tests now run in "upstream-compatible" mode by default:
- `restrict_public_statuses: false` in test environment
- Helper methods for tests that need to verify restriction behavior
- CI can run all upstream tests without modification

## Branch Strategy

### Recommended Git Workflow

```bash
# 1. Set up upstream remote
git remote add upstream https://github.com/mastodon/mastodon.git

# 2. Create a clean upstream tracking branch
git checkout -b upstream-main
git fetch upstream main
git reset --hard upstream/main
git push origin upstream-main

# 3. Keep your main branch for development
git checkout freq-main  # Your main development branch

# 4. For updates, merge upstream changes
git fetch upstream main
git checkout upstream-main
git reset --hard upstream/main
git push origin upstream-main

git checkout freq-main
git merge upstream-main  # This should have fewer conflicts now
```

### When Merge Conflicts Occur

1. **Identify the conflict type:**
   - Configuration conflicts → Update your config values
   - Logic conflicts → Ensure your changes use the new policy approach
   - Test conflicts → Use the visibility helpers

2. **For recurring conflicts:**
   - Consider moving more logic to configuration
   - Use conditional logic instead of replacing upstream code
   - Create wrapper methods instead of modifying existing ones

## Development Workflow

### Adding New Restrictions

Instead of modifying core models directly:

```ruby
# ❌ DON'T: Modify upstream code directly
validates :some_field, inclusion: { in: restricted_values }, if: -> { some_condition }

# ✅ DO: Use policy classes and configuration
validate :validate_some_field_restrictions

private

def validate_some_field_restrictions
  return unless SomePolicy.restrictions_enabled?
  # Your validation logic here
end
```

### Testing Changes

```ruby
# Use helpers for upstream-compatible tests
RSpec.describe 'some feature' do
  it 'works with public statuses' do
    status = create_public_status  # Uses proper permissions automatically
    # Test logic here
  end
  
  it 'respects visibility restrictions' do
    with_visibility_restrictions do
      # Test your custom behavior here
    end
  end
end
```

### Configuration Management

Fork-specific settings go in `config/settings.yml`:

```yaml
defaults: &defaults
  # Existing upstream settings...
  
  # Fork-specific settings (group together)
  restrict_public_statuses: true
  some_other_restriction: true
  allowed_roles: ['Owner', 'Admin']

test:
  <<: *defaults
  # Override for test compatibility
  restrict_public_statuses: false
  some_other_restriction: false
```

## CI/CD Setup

### Environment Variables

Set these in your CI environment:

```bash
# Ensure test mode runs upstream-compatible
RAILS_ENV=test
DB_NAME=mastodon_test
# ... other standard Mastodon test vars
```

### Test Commands

```bash
# Run all tests (should pass with upstream compatibility)
bundle exec rspec

# Run only fork-specific tests
bundle exec rspec spec/lib/status_visibility_policy_spec.rb
bundle exec rspec --tag fork_specific  # If you tag your custom tests
```

## Deployment

### Production Environment

Your production settings should enable restrictions:

```yaml
production:
  <<: *defaults
  restrict_public_statuses: true
  # Other production-specific overrides
```

### Environment Variables

If you need runtime configuration:

```ruby
# In your policy classes, you can also check ENV vars:
def self.restrictions_enabled?
  return ENV['DISABLE_RESTRICTIONS'] != 'true' if Rails.env.production?
  Setting.restrict_public_statuses
end
```

## Troubleshooting

### Tests Failing After Upstream Merge

1. **Check if new tests assume public statuses work:**
   ```ruby
   # Update test to use helper
   let(:status) { create_public_status }  # Instead of Fabricate(:status, visibility: :public)
   ```

2. **Check if new validations conflict with your restrictions:**
   - Look for new validations in Status model
   - Ensure your policy class handles new cases

3. **Check if settings.yml structure changed:**
   - Merge any new default settings
   - Ensure your custom settings are preserved

### Merge Conflicts in Key Files

- `app/models/concerns/status/visibility.rb`: Your changes should be minimal now
- `config/settings.yml`: Add new upstream settings, preserve your custom ones
- Test files: Use your helper methods instead of direct Fabricate calls

## Future Considerations

### When Upstream Changes Core Logic

If upstream modifies status visibility logic significantly:

1. Update your `StatusVisibilityPolicy` class to handle new cases
2. Add new configuration options as needed
3. Update tests to cover new scenarios
4. Consider if your restrictions still make sense

### Adding More Restrictions

Follow the same pattern:
1. Add configuration settings
2. Create/update policy classes  
3. Add validation methods that call the policy
4. Create test helpers
5. Add environment-specific overrides for test compatibility

This approach keeps your changes maintainable and reduces merge conflicts over time.