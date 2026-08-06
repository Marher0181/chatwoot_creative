# FORK: el webhook de Messenger trae el origen del anuncio en `referral`, o dentro
# de `postback.referral` cuando el usuario abre el hilo por primera vez. Core no lo
# expone, así que lo agregamos aquí para que el builder pueda leerlo.
module Custom::Integrations::Facebook::MessageParser
  def referral
    @messaging['referral'] || @messaging.dig('postback', 'referral')
  end
end
