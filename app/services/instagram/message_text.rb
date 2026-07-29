class Instagram::MessageText < Instagram::BaseMessageText
  # Documented denials of the user-profile endpoint, not worth paging anyone over:
  # 230 user consent required (sender never messaged the account before, e.g. ad-initiated
  # threads), 9010 no matching Instagram user (Meta's app-review bot), 100 object missing
  # or privacy-restricted.
  # https://developers.facebook.com/docs/messenger-platform/instagram/features/user-profile/#user-consent
  EXPECTED_PROFILE_ERROR_CODES = [100, 230, 9010].freeze

  attr_reader :messaging

  def fetch_instagram_user(ig_scope_id)
    fields = 'name,username,profile_pic,follower_count,is_user_follow_business,is_business_follow_user,is_verified_user'
    url = "#{base_uri}/#{ig_scope_id}?fields=#{fields}&access_token=#{@inbox.channel.access_token}"

    response = HTTParty.get(url)

    return process_successful_response(response) if response.success?

    handle_error_response(response, ig_scope_id) || {}
  end

  private

  def process_successful_response(response)
    result = JSON.parse(response.body).with_indifferent_access
    {
      'name' => result['name'],
      'username' => result['username'],
      'profile_pic' => result['profile_pic'],
      'id' => result['id'],
      'follower_count' => result['follower_count'],
      'is_user_follow_business' => result['is_user_follow_business'],
      'is_business_follow_user' => result['is_business_follow_user'],
      'is_verified_user' => result['is_verified_user']
    }.with_indifferent_access
  end

  # Returns nothing on purpose: the caller falls back to #unknown_user so the inbound
  # message is never lost because we could not read the sender's profile.
  def handle_error_response(response, ig_scope_id)
    parsed_response = response.parsed_response
    parsed_response = JSON.parse(parsed_response) if parsed_response.is_a?(String)
    error_message = parsed_response.dig('error', 'message')
    error_code = parsed_response.dig('error', 'code')

    # https://developers.facebook.com/docs/messenger-platform/error-codes
    # Access token has expired or become invalid.
    channel.authorization_error! if error_code == 190

    Rails.logger.warn("[InstagramUserFetchError]: account_id #{@inbox.account_id} inbox_id #{@inbox.id} ig_scope_id #{ig_scope_id}")
    Rails.logger.warn("[InstagramUserFetchError]: #{error_message} #{error_code}")

    return if EXPECTED_PROFILE_ERROR_CODES.include?(error_code)

    exception = StandardError.new("#{error_message} (Code: #{error_code}, IG Scope ID: #{ig_scope_id})")
    ChatwootExceptionTracker.new(exception, account: @inbox.account).capture_exception
    nil
  end

  def base_uri
    "https://graph.instagram.com/#{GlobalConfigService.load('INSTAGRAM_API_VERSION', 'v22.0')}"
  end

  def create_message
    return unless @contact_inbox

    Messages::Instagram::MessageBuilder.new(@messaging, @inbox, outgoing_echo: agent_message_via_echo?).perform
  end
end
