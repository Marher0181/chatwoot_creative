# FORK: dueño de la canned response, para la visibilidad creador + admins.
# NULL = respuestas anteriores al fork, compartidas con todo el equipo.
class AddUserToCannedResponses < ActiveRecord::Migration[7.1]
  def change
    add_reference :canned_responses, :user, null: true, index: true, foreign_key: { on_delete: :nullify }
  end
end
