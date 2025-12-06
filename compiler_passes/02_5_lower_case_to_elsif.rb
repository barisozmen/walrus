# frozen_string_literal: true

require_relative 'base'

module Walrus
  # Lowers Case nodes to ElsIf nodes with equality comparisons
  #
  # Example:
  #   case x { when 1 { a } when 2 { b } else { c } }
  # =>
  #   if x == 1 { a } elsif x == 2 { b } else { c }
  #
  # Then LowerElsIfToIf handles the elsif lowering
  class LowerCaseToElsIf < AstTransformerBasedCompilerPass
    def transform_case(node, context)
      # Transform test expression and else block
      test_expr = transform(node.test_expr, context)
      else_block = transform(node.else_block, context)

      return If.new(BinOp.new('==', test_expr, test_expr), [], else_block) if node.when_branches.empty?

      # First when becomes the initial if condition
      first_when = node.when_branches.first
      first_condition = BinOp.new('==', test_expr, transform(first_when.match_expr, context))
      first_then_block = transform(first_when.then_block, context)

      # Rest become elsif branches
      elsif_branches = node.when_branches[1..-1].map do |when_branch|
        condition = BinOp.new('==', test_expr, transform(when_branch.match_expr, context))
        ElsIfBranch.new(condition, transform(when_branch.then_block, context))
      end

      ElsIf.new(first_condition, first_then_block, elsif_branches, else_block)
    end
  end
end
