module Career
  class Profile < ApplicationRecord
    belongs_to :account
    has_many :links,
      class_name: "Career::ProfileLink",
      foreign_key: :career_profile_id,
      dependent: :destroy,
      inverse_of: :profile
    has_many :carl_stories,
      class_name: "Career::CarlStory",
      foreign_key: :career_profile_id,
      dependent: :destroy,
      inverse_of: :profile

    validates :account_id, uniqueness: true

    scope :for_account, ->(account) { where(account_id: account.id) }
  end
end
