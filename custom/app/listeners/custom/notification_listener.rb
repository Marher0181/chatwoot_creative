module Custom::NotificationListener
  def conversation_bot_handoff(event)
    conversation, account = extract_conversation_and_account(event)
    return if conversation.pending?

    conversation.inbox.members.each do |agent|
      # FORK: no notificar a agentes restringidos sobre conversaciones que no les pertenecen
      next if restricted_agent?(account, agent) && conversation.assignee_id != agent.id

      NotificationBuilder.new(
        notification_type: 'conversation_creation',
        user: agent,
        account: account,
        primary_actor: conversation
      ).perform
    end
  end

  def conversation_created(event)
    conversation, account = extract_conversation_and_account(event)
    return if conversation.pending?

    conversation.inbox.members.each do |agent|
      # FORK: no notificar a agentes restringidos sobre conversaciones que no les pertenecen
      next if restricted_agent?(account, agent) && conversation.assignee_id != agent.id

      NotificationBuilder.new(
        notification_type: 'conversation_creation',
        user: agent,
        account: account,
        primary_actor: conversation
      ).perform
    end
  end

  private

  # FORK: sin Current en contexto de job; resolvemos el rol vía la cuenta
  def restricted_agent?(account, user)
    !account.account_users.find_by(user_id: user.id)&.administrator?
  end
end
