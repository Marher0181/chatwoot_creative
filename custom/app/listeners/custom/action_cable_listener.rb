# FORK: destinatarios realtime de eventos de conversación.
# Admins reciben todo; un agente solo si es el assignee de la conversación.
#
# ponytail: estos métodos son copias de los de core cambiando solo la línea de tokens
# (user_tokens(inbox.members) -> conversation_tokens). Si upstream cambia un método de
# evento aquí, re-sincronizar. Alternativa: PR upstream que exponga un seam de tokens.
module Custom::ActionCableListener
  include Events::Types

  def message_created(event)
    message, account = extract_message_and_account(event)
    conversation = message.conversation
    tokens = conversation_tokens(account, conversation) + contact_tokens(conversation.contact_inbox, message)

    broadcast(account, tokens, MESSAGE_CREATED, message.push_event_data)
  end

  def message_updated(event)
    message, account = extract_message_and_account(event)
    conversation = message.conversation
    tokens = conversation_tokens(account, conversation) + contact_tokens(conversation.contact_inbox, message)

    broadcast(account, tokens, MESSAGE_UPDATED, message.push_event_data.merge(previous_changes: event.data[:previous_changes]))
  end

  def first_reply_created(event)
    message, account = extract_message_and_account(event)
    conversation = message.conversation
    tokens = conversation_tokens(account, conversation)

    broadcast(account, tokens, FIRST_REPLY_CREATED, message.push_event_data)
  end

  def conversation_created(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = conversation_tokens(account, conversation) + contact_inbox_tokens(conversation.contact_inbox)

    broadcast(account, tokens, CONVERSATION_CREATED, conversation.push_event_data)
  end

  def conversation_read(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = conversation_tokens(account, conversation)

    broadcast(account, tokens, CONVERSATION_READ, conversation.push_event_data)
  end

  def conversation_status_changed(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = conversation_tokens(account, conversation) + contact_inbox_tokens(conversation.contact_inbox)

    broadcast(account, tokens, CONVERSATION_STATUS_CHANGED, conversation.push_event_data)
  end

  def conversation_updated(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = conversation_tokens(account, conversation) + contact_inbox_tokens(conversation.contact_inbox)

    broadcast(account, tokens, CONVERSATION_UPDATED, conversation.push_event_data)
  end

  def conversation_unread_count_changed(event)
    account, inbox_members = ::Conversations::UnreadCounts::BroadcastScope.new(event).perform
    return if account.blank? || !account.feature_enabled?('conversation_unread_counts')

    conversation = event.data[:conversation]
    tokens = conversation ? conversation_tokens(account, conversation) : user_tokens(account, inbox_members)

    broadcast(account, tokens, CONVERSATION_UNREAD_COUNT_CHANGED, {})
  end

  def assignee_changed(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = conversation_tokens(account, conversation)

    broadcast(account, tokens, ASSIGNEE_CHANGED, conversation.push_event_data)
  end

  def team_changed(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = conversation_tokens(account, conversation)

    broadcast(account, tokens, TEAM_CHANGED, conversation.push_event_data)
  end

  def conversation_contact_changed(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = conversation_tokens(account, conversation)

    broadcast(account, tokens, CONVERSATION_CONTACT_CHANGED, conversation.push_event_data)
  end

  private

  def typing_event_listener_tokens(account, conversation, user)
    current_user_token = if user.is_a?(Contact)
                           conversation.contact_inbox.pubsub_token
                         elsif user.respond_to?(:pubsub_token)
                           user.pubsub_token
                         end

    tokens = conversation_tokens(account, conversation) + [conversation.contact_inbox.pubsub_token]
    current_user_token.present? ? tokens - [current_user_token] : tokens
  end

  # FORK: assignee + admins; los demás agentes no reciben eventos de la conversación
  def conversation_tokens(account, conversation)
    admin_tokens = account.administrators.pluck(:pubsub_token)
    ([conversation.assignee&.pubsub_token] + admin_tokens).compact.uniq
  end
end
