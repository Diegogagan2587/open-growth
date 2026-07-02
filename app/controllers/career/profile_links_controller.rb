module Career
  class ProfileLinksController < ApplicationController
    before_action :set_profile

    def create
      link = @profile.links.new(link_params)

      if link.save
        redirect_to career_profile_path, notice: "Profile link added"
      else
        redirect_to career_profile_path, alert: link.errors.full_messages.to_sentence
      end
    end

    def destroy
      @profile.links.find(params[:id]).destroy
      redirect_to career_profile_path, notice: "Profile link removed"
    end

    private

    def set_profile
      @profile = Current.account.career_profile || Current.account.create_career_profile!
    end

    def link_params
      params.require(:career_profile_link).permit(:name, :url)
    end
  end
end
