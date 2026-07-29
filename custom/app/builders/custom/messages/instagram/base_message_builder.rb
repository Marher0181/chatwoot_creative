# FORK: los hilos iniciados desde un anuncio (Click to Instagram Direct) traen el contexto de la
# campaña en el webhook de Meta, pero core lo descarta: message_params solo guarda
# in_reply_to_external_id. Lo guardamos en content_attributes[:referral], el mismo lugar donde core
# ya lo guarda para WhatsApp Cloud y Twilio, así viaja solo en los webhooks salientes y en la API.
#
# Se antepone a la clase base, así que cubre los dos canales de Instagram: ni
# Messages::Instagram::MessageBuilder ni Messages::Instagram::Messenger::MessageBuilder
# redefinen message_params.
module Custom::Messages::Instagram::BaseMessageBuilder
  private

  def message_params
    params = super
    return params if referral_attributes.blank?

    params[:content_attributes][:referral] = referral_attributes
    params
  end

  # Los hilos desde anuncio traen el referral dentro del mensaje; los eventos de referral estilo
  # Messenger lo traen en el envelope. Meta usa ambas formas.
  def referral_attributes
    @referral_attributes ||= (message[:referral].presence || @messaging[:referral])&.to_h&.deep_stringify_keys || {}
  end
end
