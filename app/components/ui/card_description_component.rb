# frozen_string_literal: true

module Ui
  class CardDescriptionComponent < ViewComponent::Base
    def initialize(css_class: nil)
      @css_class = css_class
    end

    def classes
      [
        "text-sm text-muted-foreground",
        @css_class
      ].compact.join(" ")
    end
  end
end
