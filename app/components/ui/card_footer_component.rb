# frozen_string_literal: true

module Ui
  class CardFooterComponent < ViewComponent::Base
    def initialize(css_class: nil)
      @css_class = css_class
    end

    def classes
      [
        "flex items-center pt-0 mt-4",
        @css_class
      ].compact.join(" ")
    end
  end
end
