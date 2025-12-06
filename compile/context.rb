# frozen_string_literal: true

module Walrus
  @context = {}

  def self.context
    @context
  end

  def self.reset_context
    @context = {}
  end
end
