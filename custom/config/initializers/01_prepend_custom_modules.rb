# NotificationListener y Messages::Facebook::MessageBuilder no exponen prepend_mod_with
# en core, los conectamos aquí. El resto (ConversationPolicy/ConversationFinder/
# ActionCableListener) se auto-antepone vía el prepend_mod_with que ya trae cada archivo de core.
Rails.application.config.to_prepare do
  NotificationListener.prepend(Custom::NotificationListener)
  Messages::Facebook::MessageBuilder.prepend(Custom::Messages::Facebook::MessageBuilder)

  # Instagram: los dos canales (login directo y vía página de Facebook) tampoco exponen
  # prepend_mod_with. El builder se antepone en la clase base para cubrir ambos.
  Messages::Instagram::BaseMessageBuilder.prepend(Custom::Messages::Instagram::BaseMessageBuilder)
  Instagram::MessageText.prepend(Custom::Instagram::MessageText)
  Instagram::Messenger::MessageText.prepend(Custom::Instagram::Messenger::MessageText)
end
