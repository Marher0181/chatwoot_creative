# FORK: mismo bug que en Custom::Instagram::MessageText, pero para el Instagram conectado vía
# página de Facebook. Aquí es peor: core devuelve {} en *todos* los errores de Koala (230, 9010 y
# cualquier otro), así que cualquier fallo al leer el perfil descartaba el mensaje entrante.
module Custom::Instagram::Messenger::MessageText
  private

  def ensure_contact(ig_scope_id)
    find_or_create_contact(fetch_instagram_user(ig_scope_id).presence || unknown_user(ig_scope_id))
  end

  # Core solo define unknown_user en el canal de login directo de Instagram.
  def unknown_user(ig_scope_id)
    { 'name' => "Unknown (IG: #{ig_scope_id})", 'id' => ig_scope_id }.with_indifferent_access
  end
end
