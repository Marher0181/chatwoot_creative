# FORK: atribución de anuncios de Instagram Ads. Cubre los dos builders de IG
# (Instagram login y Messenger) porque ambos heredan de este.
module Custom::Messages::Instagram::BaseMessageBuilder
  include Custom::AdReferral

  private

  def build_message
    super
    save_ad_referral(@messaging[:referral] || @messaging.dig(:postback, :referral))
  end
end
