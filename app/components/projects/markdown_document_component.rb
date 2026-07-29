# frozen_string_literal: true

class Projects::MarkdownDocumentComponent < ViewComponent::Base
  def initialize(markdown:)
    @markdown = markdown
  end
end
