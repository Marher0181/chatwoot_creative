# NotificationListener no expone prepend_mod_with en core, lo conectamos aquí.
# El resto (ConversationPolicy/ConversationFinder/ActionCableListener) se auto-antepone
# vía el prepend_mod_with que ya trae cada archivo de core.
Rails.application.config.to_prepare do
  NotificationListener.prepend(Custom::NotificationListener)
end
