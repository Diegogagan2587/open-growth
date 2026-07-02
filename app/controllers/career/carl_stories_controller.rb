module Career
  class CarlStoriesController < ApplicationController
    before_action :set_profile
    before_action :set_story, only: [ :edit, :update, :destroy ]

    def create
      story = @profile.carl_stories.new(story_params)

      if story.save
        redirect_to career_profile_path, notice: "CARL story added"
      else
        redirect_to career_profile_path, alert: story.errors.full_messages.to_sentence
      end
    end

    def edit
    end

    def update
      if @story.update(story_params)
        redirect_to career_profile_path, notice: "CARL story updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @story.destroy
      redirect_to career_profile_path, notice: "CARL story removed"
    end

    private

    def set_profile
      @profile = Current.account.career_profile || Current.account.create_career_profile!
    end

    def set_story
      @story = @profile.carl_stories.find(params[:id])
    end

    def story_params
      params.require(:career_carl_story).permit(:behavioral_question, :context, :action, :result, :learning)
    end
  end
end
