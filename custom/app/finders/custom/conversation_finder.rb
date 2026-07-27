module Custom::ConversationFinder
  # FORK: agente restringido solo cuenta lo propio; el resto de pestañas en 0
  def perform
    result = super
    result[:count] = restricted_counts(result[:count]) if restricted_agent?
    result
  end

  def perform_meta_only
    result = super
    result[:count] = restricted_counts(result[:count]) if restricted_agent?
    result
  end

  private

  # FORK: agente restringido solo ve lo propio, ignorando assignee_type del param
  def filter_by_assignee_type
    return super unless restricted_agent?

    @conversations = @conversations.where(assignee_id: current_user.id)
  end

  def restricted_counts(count)
    mine = count[:mine_count]
    { mine_count: mine, assigned_count: mine, unassigned_count: 0, all_count: mine }
  end

  # @is_admin lo setea el initialize original (robusto fuera del request-scope)
  def restricted_agent?
    !@is_admin
  end
end
