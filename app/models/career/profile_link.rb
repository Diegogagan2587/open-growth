module Career
  class ProfileLink < ApplicationRecord
    belongs_to :profile,
      class_name: "Career::Profile",
      foreign_key: :career_profile_id,
      inverse_of: :links

    validates :name, :url, presence: true
  end
end
