# frozen_string_literal: true

class Projects::MarkdownDocumentComponent < ViewComponent::Base
  def initialize(markdown:, title: "Document")
    @markdown = markdown
    @title = title
  end
end
