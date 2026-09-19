# frozen_string_literal: true

module Ui
  class DialogComponent < ViewComponent::Base
    def initialize(title: nil, description: nil, id: nil, show: false)
      @title = title
      @description = description
      @id = id
      @show = show
    end

    def title_id
      "#{@id || object_id}-title"
    end
  end
end
