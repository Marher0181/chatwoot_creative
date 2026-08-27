# FORK: filtra el listado y el acceso por id con la visibilidad creador + admins.
module Custom::Api::V1::Accounts::CannedResponsesController
  private

  def canned_responses
    super.visible_to(Current.account_user)
  end

  def fetch_canned_response
    @canned_response = Current.account.canned_responses.visible_to(Current.account_user).find(params[:id])
  end
end
