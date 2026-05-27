# frozen_string_literal: true

module Ui
  class CardHeaderComponent < ViewComponent::Base
    def initialize(css_class: nil)
      @css_class = css_class
    end

    def classes
      [
        "relative flex flex-col space-y-1.5 mb-4",
        @css_class
      ].compact.join(" ")
    end
  end
end
