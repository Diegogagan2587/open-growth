require "test_helper"

class Career::ProfileTest < ActiveSupport::TestCase
  test "belongs to an account" do
    profile = Career::Profile.new(linkedin_url: "https://linkedin.com/in/example")

    assert_not profile.valid?
    assert_includes profile.errors[:account], "must exist"
  end

  test "allows one profile per account" do
    account = accounts(:one)
    Career::Profile.create!(account: account, linkedin_url: "https://linkedin.com/in/one")
    duplicate = Career::Profile.new(account: account, github_url: "https://github.com/one")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:account_id], "has already been taken"
  end

  test "fields are optional beyond account" do
    profile = Career::Profile.new(account: accounts(:one))

    assert profile.valid?
  end

  test "destroys links and carl stories with profile" do
    profile = Career::Profile.create!(account: accounts(:one))
    profile.links.create!(name: "Blog", url: "https://blog.example.com")
    profile.carl_stories.create!(behavioral_question: "Tell me about impact.")

    assert_difference("Career::ProfileLink.count", -1) do
      assert_difference("Career::CarlStory.count", -1) do
        profile.destroy
      end
    end
  end
end
