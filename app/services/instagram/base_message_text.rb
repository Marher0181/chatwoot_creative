class Instagram::BaseMessageText < Instagram::WebhooksBaseService
  attr_reader :messaging

  def initialize(messaging, channel)
    @messaging = messaging
    super(channel)
  end

  def perform
    connected_instagram_id, contact_id = instagram_and_contact_ids
    inbox_channel(connected_instagram_id)

    return if @inbox.blank?

    if @inbox.channel.reauthorization_required?
      Rails.logger.info("Skipping message processing as reauthorization is required for inbox #{@inbox.id}")
      return
    end

    return unsend_message if message_is_deleted?

    ensure_contact(contact_id) if contacts_first_message?(contact_id)

    create_message
  end

  private

  def instagram_and_contact_ids
    if agent_message_via_echo?
      [@messaging[:sender][:id], @messaging[:recipient][:id]]
    else
      [@messaging[:recipient][:id], @messaging[:sender][:id]]
    end
  end

  def agent_message_via_echo?
    @messaging[:message][:is_echo].present?
  end

  def message_is_deleted?
    @messaging[:message][:is_deleted].present?
  end

  # if contact was present before find out contact_inbox to create message
  def contacts_first_message?(ig_scope_id)
    @contact_inbox = @inbox.contact_inboxes.where(source_id: ig_scope_id).last
    @contact_inbox.blank? && @inbox.channel.instagram_id.present?
  end

  def unsend_message
    message_to_delete = @inbox.messages.find_by(
      source_id: @messaging[:message][:mid]
    )
    return if message_to_delete.blank?

    message_to_delete.attachments.destroy_all
    message_to_delete.update!(content: I18n.t('conversations.messages.deleted'), deleted: true)
  end

  # Fetching the Instagram profile is best-effort: Instagram denies profile access for users
  # who have not messaged the account before (error 230), which is exactly the case for
  # ad-initiated threads. Fall back to a contact built from the scope id we already have,
  # because without a contact_inbox #create_message drops the inbound message entirely,
  # leaving the conversation with no incoming message — which then makes can_reply? false
  # and blocks agents behind the messaging window even though the customer wrote first.
  def ensure_contact(ig_scope_id)
    find_or_create_contact(fetch_instagram_user(ig_scope_id).presence || unknown_user(ig_scope_id))
  end

  def unknown_user(ig_scope_id)
    { 'name' => "Unknown (IG: #{ig_scope_id})", 'id' => ig_scope_id }.with_indifferent_access
  end

  # Methods to be implemented by subclasses
  def fetch_instagram_user(ig_scope_id)
    raise NotImplementedError, "#{self.class} must implement #fetch_instagram_user"
  end

  def create_message
    raise NotImplementedError, "#{self.class} must implement #create_message"
  end
end
