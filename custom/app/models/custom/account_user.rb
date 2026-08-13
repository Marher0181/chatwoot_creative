module Custom::AccountUser
  # FORK: el estado de disponibilidad es fijo por defecto — no se apaga solo cuando el agente
  # deja de usar el dashboard, solo cambia si lo cambia a mano (web o app movil).
  # La columna trae default TRUE en core y el formulario de invitacion no envia el campo,
  # asi que lo forzamos al crear. Sigue siendo editable despues desde el menu de perfil.
  def self.prepended(base)
    base.before_create { self.auto_offline = false }
  end

  # FORK: core solo activa push_conversation_assignment, con lo que al agente le suena el movil
  # al asignarsele la conversacion pero no con los mensajes siguientes. Sumamos ese flag.
  def create_notification_setting
    super
    user.notification_settings.find_by!(account_id: account.id).update!(push_assigned_conversation_new_message: true)
  end
end
