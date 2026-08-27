# Messages::Facebook::MessageBuilder y los builders de Instagram no exponen prepend_mod_with
# en core, los conectamos aquí. El resto (ConversationPolicy/ConversationFinder/
# ActionCableListener/AccountUser) se auto-antepone vía el prepend_mod_with que ya trae cada
# archivo de core.
Rails.application.config.to_prepare do
  Messages::Facebook::MessageBuilder.prepend(Custom::Messages::Facebook::MessageBuilder)
  Messages::Instagram::BaseMessageBuilder.prepend(Custom::Messages::Instagram::BaseMessageBuilder)
  Integrations::Facebook::MessageParser.prepend(Custom::Integrations::Facebook::MessageParser)
  CannedResponse.include(Custom::CannedResponse)
  Api::V1::Accounts::CannedResponsesController.prepend(Custom::Api::V1::Accounts::CannedResponsesController)
end
