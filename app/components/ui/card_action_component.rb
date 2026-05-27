# frozen_string_literal: true

module Ui
  class CardActionComponent < ViewComponent::Base
    def initialize(css_class: nil)
      @css_class = css_class
    end

    def classes
      [
        "absolute top-4 right-4",
        @css_class
      ].compact.join(" ")
    end
  end
end
