# frozen_string_literal: true

module Ui
  class CardComponent < ViewComponent::Base
    SIZE_CLASSES = {
      default: "p-6",
      sm: "p-4"
    }.freeze

    def initialize(size: :default, css_class: nil)
      @size = normalize_size(size)
      @css_class = css_class
    end

    def classes
      [
        "rounded-lg border border-border bg-card text-card-foreground shadow-sm",
        SIZE_CLASSES.fetch(@size),
        @css_class
      ].compact.join(" ")
    end

    private

    def normalize_size(size)
      size = size.to_sym
      return size if SIZE_CLASSES.key?(size)

      :default
    end
  end
end
