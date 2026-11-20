class SettingsController < ApplicationController
  def edit
    @section = settings_section
    @category_count = Category.for_account(Current.account).count if @section == "finance" && Current.account.present?
  end

  def update
    if Current.user.update(settings_params)
      redirect_to edit_settings_path(section: "general"), notice: t("settings.updated")
    else
      @section = "general"
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:user).permit(:locale, :theme_palette, :time_zone)
  end

  def settings_section
    section = params[:section].presence_in(%w[general finance])
    section || "general"
  end
end
