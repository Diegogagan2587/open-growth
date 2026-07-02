require "test_helper"

class Career::ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    sign_in_as(@user, @account)
  end

  test "shows empty profile hub when profile does not exist" do
    get career_profile_path

    assert_response :success
    assert_select "h1", "Career profile"
    assert_select "form[action='#{career_profile_path}']"
    assert_select "input[name='career_profile[linkedin_url]']"
    assert_select "textarea[name='career_profile[cover_letter_snippet]']"
  end

  test "update creates current account profile" do
    assert_difference("Career::Profile.count", 1) do
      patch career_profile_path, params: {
        career_profile: {
          linkedin_url: "https://linkedin.com/in/example",
          github_url: "https://github.com/example",
          website_url: "https://example.com",
          resume_url: "https://example.com/resume.pdf",
          email: "person@example.com",
          phone: "+1 555 0100",
          location: "Remote",
          headline: "Rails engineer",
          bio: "Builds Rails apps.",
          elevator_pitch: "I build useful software quickly.",
          unique_selling_point: "Finance and Rails product experience.",
          cover_letter_snippet: "I am interested in this role.",
          salary_preferences: "Open to market range.",
          notes: "Use for applications."
        }
      }
    end

    assert_redirected_to career_profile_path
    profile = @account.reload.career_profile
    assert_equal "https://github.com/example", profile.github_url
    assert_equal "Rails engineer", profile.headline
    assert_equal "I build useful software quickly.", profile.elevator_pitch
    assert_equal "Finance and Rails product experience.", profile.unique_selling_point
  end

  test "update does not overwrite another account profile" do
    other_profile = Career::Profile.create!(
      account: accounts(:two),
      github_url: "https://github.com/other"
    )

    patch career_profile_path, params: {
      career_profile: {
        account_id: accounts(:two).id,
        github_url: "https://github.com/current"
      }
    }

    assert_redirected_to career_profile_path
    assert_equal "https://github.com/other", other_profile.reload.github_url
    assert_equal "https://github.com/current", @account.reload.career_profile.github_url
  end

  test "show renders stored profile resources" do
    profile = Career::Profile.create!(
      account: @account,
      linkedin_url: "https://linkedin.com/in/example",
      github_url: "https://github.com/example",
      website_url: "https://example.com",
      resume_url: "https://example.com/resume.pdf",
      headline: "Rails engineer",
      elevator_pitch: "Concise pitch",
      unique_selling_point: "Strong USP",
      cover_letter_snippet: "Reusable cover letter text"
    )
    profile.links.create!(name: "Blog", url: "https://blog.example.com")
    profile.carl_stories.create!(
      behavioral_question: "Tell me about a hard problem.",
      context: "Legacy process",
      action: "Automated it",
      result: "Saved time",
      learning: "Measure first"
    )

    get career_profile_path

    assert_response :success
    assert_select "a[href='https://linkedin.com/in/example']", "LinkedIn"
    assert_select "input[value='https://github.com/example']"
    assert_select "input[value='https://example.com']"
    assert_select "input[value='https://example.com/resume.pdf']"
    assert_select "input[value='Rails engineer']"
    assert_select "textarea", text: "Concise pitch"
    assert_select "textarea", text: "Strong USP"
    assert_select "textarea", text: "Reusable cover letter text"
    assert_select "a[href='https://blog.example.com']", text: "https://blog.example.com"
    assert_select "h3", "Tell me about a hard problem."
    assert_select "p", text: /Context: Legacy process/
    assert_select "a[data-turbo-frame='career_carl_story_panel']", "Edit"
  end

  test "creates and destroys custom links for current account profile" do
    assert_difference("Career::ProfileLink.count", 1) do
      post career_profile_links_path, params: {
        career_profile_link: {
          name: "Blog",
          url: "https://blog.example.com"
        }
      }
    end

    link = @account.reload.career_profile.links.last
    assert_redirected_to career_profile_path
    assert_equal "Blog", link.name

    assert_difference("Career::ProfileLink.count", -1) do
      delete career_profile_link_path(link)
    end

    assert_redirected_to career_profile_path
  end

  test "creates and destroys carl stories for current account profile" do
    assert_difference("Career::CarlStory.count", 1) do
      post career_profile_carl_stories_path, params: {
        career_carl_story: {
          behavioral_question: "Tell me about conflict.",
          context: "Team disagreed",
          action: "Facilitated decision",
          result: "Shipped",
          learning: "Clarify constraints"
        }
      }
    end

    story = @account.reload.career_profile.carl_stories.last
    assert_redirected_to career_profile_path
    assert_equal "Tell me about conflict.", story.behavioral_question
    assert_equal "Clarify constraints", story.learning

    assert_difference("Career::CarlStory.count", -1) do
      delete career_profile_carl_story_path(story)
    end

    assert_redirected_to career_profile_path
  end

  test "updates carl stories for current account profile" do
    profile = Career::Profile.create!(account: @account)
    story = profile.carl_stories.create!(
      behavioral_question: "Tell me about conflict.",
      context: "Team disagreed",
      action: "Facilitated decision",
      result: "Shipped",
      learning: "Clarify constraints"
    )

    patch career_profile_carl_story_path(story), params: {
      career_carl_story: {
        behavioral_question: "Tell me about leadership.",
        context: "Project was stuck",
        action: "Aligned the team",
        result: "Released on time",
        learning: "Make tradeoffs explicit"
      }
    }

    assert_redirected_to career_profile_path
    story.reload
    assert_equal "Tell me about leadership.", story.behavioral_question
    assert_equal "Project was stuck", story.context
    assert_equal "Aligned the team", story.action
    assert_equal "Released on time", story.result
    assert_equal "Make tradeoffs explicit", story.learning
  end

  test "edits carl story in drawer form" do
    profile = Career::Profile.create!(account: @account)
    story = profile.carl_stories.create!(
      behavioral_question: "Tell me about conflict.",
      context: "Team disagreed"
    )

    get edit_career_profile_carl_story_path(story), xhr: true

    assert_response :success
    assert_select "h1", "Edit CARL story"
    assert_select "form[action='#{career_profile_carl_story_path(story)}']"
    assert_select "textarea[name='career_carl_story[behavioral_question]']", text: "Tell me about conflict."
    assert_select "textarea[name='career_carl_story[context]']", text: "Team disagreed"
  end

  test "turbo frame receives carl story edit panel html" do
    profile = Career::Profile.create!(account: @account)
    story = profile.carl_stories.create!(
      behavioral_question: "Tell me about ownership.",
      context: "Critical project"
    )

    get edit_career_profile_carl_story_path(story), headers: { "Turbo-Frame" => "career_carl_story_panel" }

    assert_response :success
    assert_select "turbo-frame#career_carl_story_panel"
    assert_includes response.body, "Edit CARL story"
    assert_includes response.body, "Tell me about ownership."
    assert_includes response.body, "Critical project"
    assert_no_match "<!DOCTYPE html>", response.body
  end
end
