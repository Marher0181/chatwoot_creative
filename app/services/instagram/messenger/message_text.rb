class Instagram::Messenger::MessageText < Instagram::BaseMessageText
  private

  def fetch_instagram_user(ig_scope_id)
    k = Koala::Facebook::API.new(@inbox.channel.page_access_token) if @inbox.facebook?
    k.get_object(ig_scope_id) || {}
  rescue Koala::Facebook::AuthenticationError => e
    handle_authentication_error(e)
    {}
  rescue StandardError, Koala::Facebook::ClientError => e
    handle_client_error(e)
    {}
  end

  def handle_authentication_error(error)
    @inbox.channel.authorization_error!
    Rails.logger.warn("Authorization error for account #{@inbox.account_id} for inbox #{@inbox.id}")
    ChatwootExceptionTracker.new(error, account: @inbox.account).capture_exception
  end

  # Logs and swallows expected denials; the caller falls back to #unknown_user, so a
  # profile we cannot read never costs us the inbound message.
  def handle_client_error(error)
    # Handle error code 230: User consent is required to access user profile
    # This typically occurs when the connected Instagram account attempts to send a message to a user
    # who has never messaged this Instagram account before, which is the norm for ad-initiated threads.
    if error.message.include?('230')
      Rails.logger.warn error
      return
    end

    # Handle error code 9010: No matching Instagram user
    # This occurs when trying to fetch an Instagram user that doesn't exist or is not accessible
    if error.message.include?('9010')
      Rails.logger.warn("[Instagram User Not Found]: account_id #{@inbox.account_id} inbox_id #{@inbox.id}")
      Rails.logger.warn("[Instagram User Not Found]: #{error.message}")
      Rails.logger.warn("[Instagram User Not Found]: #{error}")
      return
    end

    Rails.logger.warn("[FacebookUserFetchClientError]: account_id #{@inbox.account_id} inbox_id #{@inbox.id}")
    Rails.logger.warn("[FacebookUserFetchClientError]: #{error.message}")
    ChatwootExceptionTracker.new(error, account: @inbox.account).capture_exception
  end

  def create_message
    return unless @contact_inbox

    Messages::Instagram::Messenger::MessageBuilder.new(@messaging, @inbox, outgoing_echo: agent_message_via_echo?).perform
  end
end
