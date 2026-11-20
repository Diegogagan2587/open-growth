# frozen_string_literal: true

module Ui
  class ButtonComponent < ViewComponent::Base
    BASE_CLASSES = "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-[color,box-shadow,border-color,background-color] outline-none disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 shrink-0 focus-visible:border-ring focus-visible:ring-ring/40 focus-visible:ring-[3px] aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive"

    VARIANT_CLASSES = {
      default: "border border-transparent bg-primary text-primary-foreground shadow-sm hover:bg-primary/92",
      destructive: "border border-transparent bg-destructive text-white shadow-sm hover:bg-destructive/90 focus-visible:ring-destructive/20 dark:focus-visible:ring-destructive/40",
      outline: "border border-input bg-card text-foreground shadow-sm hover:bg-muted/60 hover:text-foreground",
      secondary: "border border-border bg-secondary text-foreground shadow-sm hover:bg-secondary/85",
      ghost: "border border-transparent hover:bg-muted/55 hover:text-foreground",
      link: "text-primary underline-offset-4 hover:underline shadow-none"
    }.freeze

    SIZE_CLASSES = {
      default: "h-9 px-4 py-2 has-[>svg]:px-3",
      sm: "h-8 rounded-md gap-1.5 px-3 has-[>svg]:px-2.5",
      lg: "h-10 rounded-md px-6 has-[>svg]:px-4",
      icon: "h-9 w-9"
    }.freeze

    def initialize(href: nil, label: nil, aria_label: nil, variant: :default, size: :default, disabled: false, type: "button", method: nil, data: {}, css_class: nil, as: nil)
      @href = href
      @label = label
      @aria_label = aria_label
      @variant = normalize_variant(variant)
      @size = normalize_size(size)
      @disabled = disabled
      @type = type
      @method = method
      @data = data
      @extra_class = css_class
      @as = as || (@href.present? ? :link : :button)
    end

    def classes
      [ BASE_CLASSES, VARIANT_CLASSES.fetch(@variant), SIZE_CLASSES.fetch(@size), @extra_class ].compact.join(" ")
    end

    def link?
      @as.to_sym == :link
    end

    def tag_options
      options = { class: classes }
      options[:aria] = { label: @aria_label } if @aria_label.present?

      data_options = @data.present? ? @data.dup : {}
      if link? && @method.present?
        # Support both Turbo and legacy UJS handlers for non-GET links.
        data_options[:turbo_method] = @method unless data_options.key?(:turbo_method)
        data_options[:method] = @method unless data_options.key?(:method)
      end

      options[:data] = data_options if data_options.present?
      options[:method] = @method if @method.present? && !link?
      options[:disabled] = true if @disabled
      options.compact
    end

    private

    def normalize_variant(variant)
      return :default if variant.nil?

      variant = variant.to_sym
      return variant if VARIANT_CLASSES.key?(variant)

      :default
    end

    def normalize_size(size)
      mapped_size = case size.to_sym
      when :small
        :sm
      when :large
        :lg
      else
        size.to_sym
      end

      return mapped_size if SIZE_CLASSES.key?(mapped_size)

      :default
    end
  end
end
