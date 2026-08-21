class Financial::Accounts::ArchivesController < ApplicationController
  def create
    account = Financial::Account.for_account(Current.account).find(params[:account_id])
    account.archive!
    redirect_to finance_account_path(account), notice: "Financial account archived"
  end
end
