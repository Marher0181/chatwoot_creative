# FORK: Chatwoot solo ingiere Instagram por webhook, así que las conversaciones anteriores
# a conectar el inbox no existen. Esto las importa desde /{ig_id}/conversations
# (Instagram Login API), reutilizando contactos y saltando mensajes ya presentes.
#
# Dry-run (no escribe nada, solo cuenta):
#   rails runner 'p Custom::Instagram::HistoryImport.new(Inbox.find(ID)).perform'
# Importar de verdad:
#   rails runner 'p Custom::Instagram::HistoryImport.new(Inbox.find(ID), apply: true).perform'
class Custom::Instagram::HistoryImport
  BASE_URL = 'https://graph.instagram.com/v22.0'.freeze
  # ponytail: los 100 mensajes más recientes por conversación; si hace falta más historial,
  # aquí va la paginación del edge `messages`.
  FIELDS = 'participants,messages.limit(100){id,created_time,from,message,attachments}'.freeze

  # ponytail: durante la importación el bus de eventos se silencia — ni notificaciones, ni
  # automatizaciones, ni webhooks disparándose por mensajes de hace meses. Solo afecta a
  # este proceso (rails runner), no al Rails que atiende peticiones.
  class NullDispatcher
    def dispatch(*); end
  end

  def initialize(inbox, apply: false)
    @inbox = inbox
    @channel = inbox.channel
    @apply = apply
    @stats = { conversations: 0, messages: 0 }
  end

  def perform
    silence_events do
      each_remote_conversation { |remote| import_conversation(remote) }
    end
    @stats.merge(applied: @apply)
  end

  private

  def silence_events
    original = Rails.configuration.dispatcher
    Rails.configuration.dispatcher = NullDispatcher.new
    yield
  ensure
    Rails.configuration.dispatcher = original
  end

  def each_remote_conversation
    url = "#{BASE_URL}/#{@channel.instagram_id.presence || 'me'}/conversations"
    query = { fields: FIELDS, limit: 50, access_token: @channel.access_token }

    while url
      body = JSON.parse(HTTParty.get(url, query: query).body)
      raise "Instagram API: #{body['error']['message']}" if body['error']

      body['data'].to_a.each { |remote| yield remote }
      url = body.dig('paging', 'next')
      query = nil # la url de paginación ya trae fields y token
    end
  end

  def import_conversation(remote)
    participant = remote.dig('participants', 'data').to_a.find { |p| p['id'].to_s != @channel.instagram_id.to_s }
    messages = remote.dig('messages', 'data').to_a
                     .select { |message| message_content(message).present? }
                     .reject { |message| @inbox.messages.exists?(source_id: message['id']) }
    return if participant.nil? || messages.empty?

    @stats[:conversations] += 1
    @stats[:messages] += messages.size
    Rails.logger.info("FORK import IG: #{participant['username']} → #{messages.size} mensajes")
    return unless @apply

    conversation = find_or_create_conversation(participant)
    # Graph los devuelve del más nuevo al más viejo.
    messages.reverse_each { |message| create_message(conversation, message) }
  end

  def find_or_create_conversation(participant)
    contact_inbox = @channel.create_contact_inbox(participant['id'], participant['name'].presence || participant['username'])

    @inbox.conversations.where(contact_id: contact_inbox.contact_id).order(created_at: :desc).first ||
      @inbox.conversations.create!(
        account_id: @inbox.account_id,
        contact_id: contact_inbox.contact_id,
        contact_inbox_id: contact_inbox.id
      )
  end

  def create_message(conversation, remote)
    outgoing = remote.dig('from', 'id').to_s == @channel.instagram_id.to_s

    conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: outgoing ? :outgoing : :incoming,
      status: outgoing ? :delivered : :sent,
      content: message_content(remote),
      # El source_id de Meta hace la importación repetible y evita que SendReplyJob reenvíe nada.
      source_id: remote['id'],
      sender: outgoing ? nil : conversation.contact,
      created_at: remote['created_time']
    )
  end

  # ponytail: los adjuntos se guardan como enlace en el texto, no se re-descargan.
  def message_content(remote)
    urls = remote.dig('attachments', 'data').to_a.filter_map do |attachment|
      attachment['file_url'] || attachment.dig('image_data', 'url') || attachment.dig('video_data', 'url')
    end

    [remote['message'].presence, *urls].compact.join("\n")
  end
end
