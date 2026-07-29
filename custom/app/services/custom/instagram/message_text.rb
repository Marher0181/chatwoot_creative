# FORK: Instagram niega el perfil de quien nunca le ha escrito a la cuenta (error 230), que es
# el caso de todo hilo iniciado desde un anuncio. Core hace `find_or_create_contact(result) if
# result.present?`, así que ante ese error no creaba el contacto, #create_message salía temprano
# por su `return unless @contact_inbox` y el mensaje entrante se perdía en silencio (el 230 sale
# antes de las líneas de log, así que no quedaba ni rastro).
#
# El daño colateral era peor que el mensaje faltante: la conversación quedaba sin ningún mensaje
# entrante, y Conversations::MessageWindowService devuelve can_reply? = false cuando
# last_incoming_message es nil, así que los agentes veían el bloqueo de la ventana de 24 horas
# aunque el cliente hubiera escrito primero.
#
# Leer el perfil pasa a ser best-effort: si no se puede, el contacto se crea con el scope id que
# ya tenemos (core ya define unknown_user para esto, lo usa solo en los errores 9010 y 100).
module Custom::Instagram::MessageText
  def ensure_contact(ig_scope_id)
    find_or_create_contact(fetch_instagram_user(ig_scope_id).presence || unknown_user(ig_scope_id))
  end
end
