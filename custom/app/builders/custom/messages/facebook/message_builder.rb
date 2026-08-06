# FORK: Meta ya no devuelve first_name/last_name en GET /{psid}, así que los contactos
# nuevos de Facebook se creaban como "John Doe". El endpoint /{page_id}/conversations
# sí trae los nombres de los participantes, lo usamos como fallback.
module Custom::Messages::Facebook::MessageBuilder
  include Custom::AdReferral

  private

  # FORK: atribución de anuncios de Facebook Ads.
  def build_message
    super
    save_ad_referral(response.referral)
  end

  def process_contact_params_result(result)
    params = super
    return params if result['first_name'].present?
    # El nombre solo se usa al crear el contacto; si ya existe no gastamos una llamada a Graph.
    return params if @inbox.contact_inboxes.exists?(source_id: @sender_id)

    name = participant_name
    name.present? ? params.merge(name: name) : params
  end

  def participant_name
    channel = @inbox.channel
    # ponytail: solo la primera página (100 conversaciones más recientes). Un mensaje entrante
    # sube su conversación al tope del listado, así que el remitente nuevo siempre está ahí.
    conversations = Koala::Facebook::API.new(channel.page_access_token)
                                        .get_connections(channel.page_id, 'conversations', fields: 'participants', limit: 100)

    participants = conversations.flat_map { |conversation| conversation.dig('participants', 'data') || [] }
    participants.find { |participant| participant['id'] == @sender_id && participant['name'].present? }&.dig('name')
  rescue StandardError => e
    # Sin nombre nos quedamos con el fallback de core; nunca perdemos el mensaje por esto.
    Rails.logger.warn("FORK: no se pudo resolver el nombre de FB para #{@sender_id} en inbox #{@inbox.id}: #{e.message}")
    nil
  end
end
