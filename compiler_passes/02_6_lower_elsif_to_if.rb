# frozen_string_literal: true

require_relative 'base'

module Walrus
  # Lowers ElsIf nodes to nested If nodes
  #
  # Example:
  #   if x < 0 { a } elsif x == 0 { b } elsif x > 0 { c } else { d }
  # =>
  #   if x < 0 { a } else {
  #     if x == 0 { b } else {
  #       if x > 0 { c } else { d }
  #     }
  #   }
  class LowerElsIfToIf < AstTransformerBasedCompilerPass
    def transform_elsif(node, context)
      # First, recursively transform all children
      condition = transform(node.condition, context)
      then_block = transform(node.then_block, context)
      else_block = transform(node.else_block, context)

      # Transform elsif branches
      elsif_branches = node.elsif_branches.map do |branch|
        ElsIfBranch.new(
          transform(branch.condition, context),
          transform(branch.then_block, context)
        )
      end

      # Build nested if/else from right to left
      result = elsif_branches.reverse.reduce(else_block) do |acc, elsif_branch|
        [If.new(elsif_branch.condition, elsif_branch.then_block, acc)]
      end

      If.new(condition, then_block, result)
    end
  end
end
