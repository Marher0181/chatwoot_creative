# NotificationListener y Messages::Facebook::MessageBuilder no exponen prepend_mod_with
# en core, los conectamos aquí. El resto (ConversationPolicy/ConversationFinder/
# ActionCableListener) se auto-antepone vía el prepend_mod_with que ya trae cada archivo de core.
Rails.application.config.to_prepare do
  NotificationListener.prepend(Custom::NotificationListener)
  Messages::Facebook::MessageBuilder.prepend(Custom::Messages::Facebook::MessageBuilder)
  Messages::Instagram::BaseMessageBuilder.prepend(Custom::Messages::Instagram::BaseMessageBuilder)
  Integrations::Facebook::MessageParser.prepend(Custom::Integrations::Facebook::MessageParser)
end
