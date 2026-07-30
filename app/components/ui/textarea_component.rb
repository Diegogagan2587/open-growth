# frozen_string_literal: true

class Ui::TextareaComponent < ViewComponent::Base
  BASE_CLASSES = "flex min-h-24 w-full rounded-md border border-input bg-background px-3 py-2 text-sm text-foreground shadow-xs outline-none transition-[color,box-shadow] placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50".freeze

  def initialize(name:, value: nil, id: nil, placeholder: nil, rows: 4, required: false, disabled: false, css_class: nil, data: {})
    @name = name
    @value = value
    @id = id
    @placeholder = placeholder
    @rows = rows
    @required = required
    @disabled = disabled
    @css_class = css_class
    @data = data
  end

  def html_attributes
    {
      name: @name,
      id: @id,
      placeholder: @placeholder,
      rows: @rows,
      required: @required,
      disabled: @disabled,
      class: [ BASE_CLASSES, @css_class ].compact.join(" "),
      data: @data.presence
    }.compact
  end
end
