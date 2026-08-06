# FORK: guarda de qué anuncio viene la conversación en los custom attributes, con
# los mismos nombres que el workflow de n8n usa para WhatsApp (`ad_source`, `ad_id`,
# `ad_title`, `ad_url`), para que un solo juego de atributos sirva a los tres canales.
module Custom::AdReferral
  private

  def save_ad_referral(referral)
    return if referral.blank?
    # ponytail: solo anuncios (ADS / IG_ADS). Los otros `source` del webhook
    # (SHORTLINK, CUSTOMER_CHAT_PLUGIN) no son pauta y no se piden hoy.
    return unless referral['source'].to_s.upcase.include?('ADS')

    creative = referral['ads_context_data'] || {}
    attributes = {
      'ad_source' => @inbox.instagram? ? 'instagram' : 'facebook',
      'ad_id' => referral['ad_id'],
      'ad_title' => creative['ad_title'],
      'ad_url' => creative['photo_url'] || creative['video_url']
    }.compact_blank

    conversation.update!(custom_attributes: conversation.custom_attributes.merge(attributes))
  end
end
