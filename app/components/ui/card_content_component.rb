# frozen_string_literal: true

module Ui
  class CardContentComponent < ViewComponent::Base
    def initialize(css_class: nil)
      @css_class = css_class
    end

    def classes
      [
        "",
        @css_class
      ].compact.join(" ")
    end
  end
end
