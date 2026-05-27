# frozen_string_literal: true

module Ui
  class CardTitleComponent < ViewComponent::Base
    def initialize(css_class: nil)
      @css_class = css_class
    end

    def classes
      [
        "text-2xl font-semibold leading-none tracking-tight",
        @css_class
      ].compact.join(" ")
    end
  end
end
