# frozen_string_literal: true

class Ui::InputComponent < ViewComponent::Base
  BASE_CLASSES = "flex h-9 w-full min-w-0 rounded-md border border-input bg-background px-3 py-1 text-sm text-foreground shadow-xs transition-[color,box-shadow] outline-none file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground selection:bg-primary selection:text-primary-foreground disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px] aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive".freeze

  def initialize(name:, value: nil, id: nil, type: "text", placeholder: nil, disabled: false, required: false, aria_invalid: false, data: {}, css_class: nil, min: nil, max: nil, step: nil)
    @name = name
    @value = value
    @id = id
    @type = type
    @placeholder = placeholder
    @disabled = disabled
    @required = required
    @aria_invalid = aria_invalid
    @data = data
    @extra_class = css_class
    @min = min
    @max = max
    @step = step
  end

  def html_attributes
    {
      type: @type,
      name: @name,
      id: @id,
      value: @value,
      placeholder: @placeholder,
      disabled: @disabled,
      required: @required,
      "aria-invalid": @aria_invalid,
      data: @data.presence,
      min: @min,
      max: @max,
      step: @step,
      class: [ BASE_CLASSES, @extra_class ].compact.join(" ")
    }.compact
  end
end
