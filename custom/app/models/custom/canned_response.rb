# FORK: cada canned response pertenece a quien la creó. Un agente solo ve las suyas y las
# de los administradores; un admin las ve todas. user_id NULL = heredadas, visibles para todos.
module Custom::CannedResponse
  extend ActiveSupport::Concern

  included do
    belongs_to :user, optional: true

    before_validation(on: :create) { self.user ||= Current.user }

    scope :visible_to, lambda { |account_user|
      next all unless account_user&.agent?

      admin_ids = account_user.account.account_users.administrator.pluck(:user_id)
      where(user_id: [nil, account_user.user_id, *admin_ids])
    }
  end
end
