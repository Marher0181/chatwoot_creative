module Custom::NotificationBuilder
  private

  # FORK: solo los administradores reciben notificaciones (Inbox, email y push)
  def build_notification
    return unless AccountUser.find_by(account_id: account.id, user_id: user.id)&.administrator?

    super
  end
end
