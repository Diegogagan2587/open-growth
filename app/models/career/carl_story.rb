module Career
  class CarlStory < ApplicationRecord
    belongs_to :profile,
      class_name: "Career::Profile",
      foreign_key: :career_profile_id,
      inverse_of: :carl_stories

    validates :behavioral_question, presence: true
  end
end
