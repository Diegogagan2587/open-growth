# frozen_string_literal: true

class Ui::SelectComponent < ViewComponent::Base
  BASE_CLASSES = "flex h-9 w-full rounded-md border border-input bg-background px-3 py-1 text-sm text-foreground shadow-xs transition-[color,box-shadow] outline-none disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px] aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive".freeze

  def initialize(name:, options:, selected: nil, id: nil, disabled: false, required: false, aria_invalid: false, include_blank: nil, data: {}, css_class: nil, searchable: false)
    @name = name
    @options = options
    @selected = selected
    @id = id
    @disabled = disabled
    @required = required
    @aria_invalid = aria_invalid
    @include_blank = include_blank
    @data = data
    @extra_class = css_class
    @searchable = searchable
  end

  def rendered_options
    opts = @options
    opts = [ [ blank_label, "" ] ] + opts if include_blank_option?
    helpers.options_for_select(opts, @selected)
  end

  def html_attributes
    {
      id: @id,
      disabled: @disabled,
      required: @required,
      "aria-invalid": @aria_invalid,
      data: @data.presence,
      class: [ BASE_CLASSES, @extra_class ].compact.join(" ")
    }.compact
  end

  def searchable?
    @searchable
  end

  private

  def include_blank_option?
    @include_blank.present? || @include_blank == true
  end

  def blank_label
    return "" if @include_blank == true

    @include_blank.to_s
  end
end
