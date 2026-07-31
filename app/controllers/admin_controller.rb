# frozen_string_literal: true

class AdminController < ApplicationController
  skip_account_scoping
  before_action :require_system_admin

  private

  def require_system_admin
    head :forbidden unless Current.user&.system_admin?
  end
end
