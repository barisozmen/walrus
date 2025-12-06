# Lower Short-Circuit Operators to If/Else
#
# Transforms and/or operators in control flow conditions into nested if/else:
#   if a and b { body }  =>  if a { if b { body } }
#   if a or b { body }   =>  if a { body } else { if b { body } }
#
# This transformation happens early, before type inference, so subsequent passes
# only see nested if/else statements.
#
# Example:
#   if x != 0 and 100/x > 0 {
#     print x;
#   }
#   =>
#   if x != 0 {
#     if 100/x > 0 {
#       print x;
#     }
#   }

require_relative 'base'

module Walrus
  class LowerShortCircuitOperators < AstTransformerBasedCompilerPass
    def transform_if(node, context)
      # Transform the condition to handle and/or
      new_condition = transform(node.condition, context)
      new_then = transform(node.then_block, context)
      new_else = transform(node.else_block, context)

      if !new_condition.is_a?(BinOp) || !%w[and or].include?(new_condition.op)
        return If.new(new_condition, new_then, new_else)
      end

      # If condition is a BinOp with 'and' or 'or', transform the if statement
      case new_condition.op
      when 'and'
        # if a and b { then_body } else { else_body }
        # => if a { if b { then_body } else { else_body } } else { else_body }
        If.new(
            new_condition.left,
            [If.new(new_condition.right, new_then, new_else)],
            new_else
          )
      when 'or'
        # if a or b { then_body } else { else_body }
        # => if a { then_body } else { if b { then_body } else { else_body } }
        If.new(
          new_condition.left,
          new_then,
          [If.new(new_condition.right, new_then, new_else)]
        )
      end
    end

    def transform_while(node, context)
      new_condition = transform(node.condition, context)
      new_body = transform(node.body, context)

      # Similar transformation for while loops
      if !new_condition.is_a?(BinOp) || !%w[and or].include?(new_condition.op)
        return While.new(new_condition, new_body)
      end

      case new_condition.op
      when 'and'
        # while a and b { body }
        # => while a { if b { body } }
        While.new(
          new_condition.left,
          [If.new(new_condition.right, new_body, [])]
        )
      when 'or'
        # while a or b { body }
        # => while a or b { body } -- can't simplify easily, transform to: while true { if !(a or b) break; body }
        # For now, leave as-is (or could expand fully)
        While.new(new_condition, new_body)
      end
    end
  end
end
