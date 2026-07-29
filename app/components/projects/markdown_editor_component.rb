# frozen_string_literal: true

class Projects::MarkdownEditorComponent < ViewComponent::Base
  def initialize(form:, preview_url:)
    @form = form
    @preview_url = preview_url
  end
end
