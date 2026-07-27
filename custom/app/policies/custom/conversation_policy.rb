module Custom::ConversationPolicy
  private

  # FORK: agente no-admin solo ve conversaciones asignadas a él
  def agent_can_view_conversation?
    assigned_to_user?
  end
end
