module Career
  class ProfilesController < ApplicationController
    before_action :set_profile

    def show
    end

    def edit
    end

    def update
      if @profile.update(profile_params)
        redirect_to career_profile_path, notice: "Career profile updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_profile
      @profile = Current.account.career_profile || Current.account.build_career_profile
      @profile.links.load if @profile.persisted?
      @profile.carl_stories.load if @profile.persisted?
    end

    def profile_params
      params.require(:career_profile).permit(
        :linkedin_url,
        :github_url,
        :website_url,
        :resume_url,
        :email,
        :phone,
        :location,
        :headline,
        :bio,
        :elevator_pitch,
        :unique_selling_point,
        :cover_letter_snippet,
        :salary_preferences,
        :notes
      )
    end
  end
end
