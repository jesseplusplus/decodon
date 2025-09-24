# frozen_string_literal: true

class ProcessMentionsService < BaseService
  include Payloadable

  # Scan status for mentions and fetch remote mentioned users,
  # and create local mention pointers
  # @param [Status] status
  # @param [Circle] circle
  # @param [Boolean] save_records Whether to save records in database
  def call(status, circle = nil, save_records: true)
    @status = status
    @circle = circle
    @save_records = save_records

    return unless @status.local?

    @previous_mentions = @status.mentions.includes(:account).to_a
    @current_mentions  = []

    Status.transaction do
      scan_text!
      assign_mentions!
    end
  end

  private

  def scan_text!
    @status.text = @status.text.gsub(Account::MENTION_RE) do |match|
      username, domain = Regexp.last_match(1).split('@')

      domain = if TagManager.instance.local_domain?(domain)
                 nil
               else
                 TagManager.instance.normalize_domain(domain)
               end

      mentioned_account = Account.find_remote(username, domain)

      # Unapproved and unconfirmed accounts should not be mentionable
      next match if mentioned_account&.local? && !(mentioned_account.user_confirmed? && mentioned_account.user_approved?)

      # If the account cannot be found or isn't the right protocol,
      # first try to resolve it
      if mention_undeliverable?(mentioned_account)
        begin
          mentioned_account = ResolveAccountService.new.call(Regexp.last_match(1))
        rescue Webfinger::Error, *Mastodon::HTTP_CONNECTION_ERRORS, Mastodon::UnexpectedResponseError
          mentioned_account = nil
        end
      end

      # If after resolving it still isn't found or isn't the right
      # protocol, then give up
      next match if mention_undeliverable?(mentioned_account) || mentioned_account&.unavailable?

      mention   = @previous_mentions.find { |x| x.account_id == mentioned_account.id }
      mention ||= @current_mentions.find  { |x| x.account_id == mentioned_account.id }
      mention ||= @status.mentions.new(account: mentioned_account)

      mention.silent = false

      @current_mentions << mention

      "@#{mentioned_account.acct}"
    end

    mentioned_account_ids = @current_mentions.pluck(:account_id)

    if @circle.present?
      add_circle_mentions!(mentioned_account_ids)
    elsif @status.limited_visibility? && @status.thread&.limited_visibility?
      # If we are replying to a local status, then we'll have the complete
      # audience copied here, both local and remote. If we are replying
      # to a remote status, only local audience will be copied. Then we
      # need to send our reply to the remote author's inbox for distribution

      @status.thread.mentions.includes(:account).find_each do |mention|
        next if @status.account_id == mention.account_id && mentioned_account_ids.include?(mention.account.id)

        new_mention = @status.mentions.new(silent: true, account: mention.account)
        @current_mentions << new_mention
      end

      if @status.account_id != @status.thread.account_id && !mentioned_account_ids.include?(@status.thread.account.id)
        new_mention = @status.mentions.new(silent: true, account: @status.thread.account)
        @current_mentions << new_mention
      end
    end

    @status.save! if @save_records
  end

  def add_circle_mentions!(mentioned_account_ids)
    @circle.accounts.find_each do |target_account|
      next if mentioned_account_ids.include?(target_account.id)

      mention = @previous_mentions.find { |x| x.account_id == target_account.id }
      mention ||= @status.mentions.new(account: target_account)
      mention.silent = true
      @current_mentions << mention
    end
  end

  def assign_mentions!
    # Make sure we never mention blocked accounts
    unless @current_mentions.empty?
      mentioned_domains = @current_mentions.filter_map { |m| m.account.domain }.uniq
      blocked_domains   = Set.new(mentioned_domains.empty? ? [] : AccountDomainBlock.where(account_id: @status.account_id, domain: mentioned_domains))
      mentioned_account_ids = @current_mentions.map(&:account_id)
      blocked_account_ids = Set.new(@status.account.block_relationships.where(target_account_id: mentioned_account_ids).pluck(:target_account_id))

      dropped_mentions, @current_mentions = @current_mentions.partition { |mention| blocked_account_ids.include?(mention.account_id) || blocked_domains.include?(mention.account.domain) }
      dropped_mentions.each(&:destroy)
    end

    @current_mentions.each do |mention|
      mention.save if (mention.new_record? || mention.silent_changed?) && @save_records
    end

    # If previous mentions are no longer contained in the text, convert them
    # to silent mentions, since withdrawing access from someone who already
    # received a notification might be more confusing
    removed_mentions = @previous_mentions - @current_mentions

    Mention.where(id: removed_mentions.map(&:id), silent: false).update_all(silent: true) unless removed_mentions.empty?
  end

  def mention_undeliverable?(mentioned_account)
    mentioned_account.nil? || (!mentioned_account.local? && !mentioned_account.activitypub?)
  end
end
