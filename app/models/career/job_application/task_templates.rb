module Career
  module TaskTemplates
    Template = Struct.new(:key, :title, :priority, :due_in_days, :description, keyword_init: true)

    TEMPLATES = {
      "saved" => [
        Template.new(key: "research_company", title: "Research company", priority: "medium", due_in_days: 0),
        Template.new(key: "customize_resume", title: "Customize resume", priority: "high", due_in_days: 1),
        Template.new(key: "draft_outreach_message", title: "Draft outreach message", priority: "medium", due_in_days: 2)
      ],
      "researching" => [
        Template.new(key: "finalize_fit_decision", title: "Finalize fit decision", priority: "high", due_in_days: 1),
        Template.new(key: "prepare_tailored_resume", title: "Prepare tailored resume", priority: "high", due_in_days: 1),
        Template.new(key: "prepare_cover_note", title: "Prepare cover note", priority: "medium", due_in_days: 2)
      ],
      "applied" => [
        Template.new(key: "send_follow_up", title: "Send follow-up", priority: "high", due_in_days: 5),
        Template.new(key: "track_response_window", title: "Track response window", priority: "medium", due_in_days: 7),
        Template.new(key: "prepare_recruiter_screen_notes", title: "Prepare recruiter screen notes", priority: "medium", due_in_days: 2)
      ],
      "screening" => [
        Template.new(key: "prepare_screening_answers", title: "Prepare screening answers", priority: "high", due_in_days: 1),
        Template.new(key: "confirm_logistics", title: "Confirm logistics", priority: "medium", due_in_days: 0)
      ],
      "interviewing" => [
        Template.new(key: "prepare_interview_stories", title: "Prepare interview stories", priority: "high", due_in_days: 1),
        Template.new(key: "research_interviewer_team", title: "Research interviewer/team", priority: "medium", due_in_days: 1),
        Template.new(key: "send_thank_you_note", title: "Send thank-you note", priority: "high", due_in_days: 1)
      ],
      "technical_test" => [
        Template.new(key: "review_test_requirements", title: "Review test requirements", priority: "high", due_in_days: 0),
        Template.new(key: "plan_implementation", title: "Plan implementation", priority: "high", due_in_days: 1),
        Template.new(key: "submit_test", title: "Submit test", priority: "high", due_in_days: 3),
        Template.new(key: "follow_up_on_test", title: "Follow up on test", priority: "medium", due_in_days: 5)
      ],
      "offer" => [
        Template.new(key: "review_offer_details", title: "Review offer details", priority: "high", due_in_days: 1),
        Template.new(key: "prepare_negotiation_points", title: "Prepare negotiation points", priority: "high", due_in_days: 2)
      ],
      "rejected" => [
        Template.new(key: "capture_learnings", title: "Capture learnings", priority: "low", due_in_days: 1),
        Template.new(key: "archive_notes", title: "Archive notes", priority: "low", due_in_days: 2)
      ],
      "withdrawn" => [
        Template.new(key: "capture_learnings", title: "Capture learnings", priority: "low", due_in_days: 1),
        Template.new(key: "archive_notes", title: "Archive notes", priority: "low", due_in_days: 2)
      ],
      "ghosted" => [
        Template.new(key: "capture_learnings", title: "Capture learnings", priority: "low", due_in_days: 1),
        Template.new(key: "archive_notes", title: "Archive notes", priority: "low", due_in_days: 2)
      ]
    }.freeze

    def self.for_status(status)
      TEMPLATES.fetch(status.to_s, [])
    end

    def self.find(status:, key:)
      for_status(status).find { |template| template.key == key.to_s }
    end
  end
end
