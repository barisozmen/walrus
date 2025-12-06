# precedence.rb
#
# Operator precedence logic for formatting expressions.
# Determines when parentheses are needed based on operator precedence and associativity.

module Precedence
  # Determine if parentheses are needed based on operator precedence
  def needs_parens?(child_expr, parent_expr, position)
    return false unless child_expr.is_a?(BinOp) && parent_expr.is_a?(BinOp)

    child_precedence = operator_precedence(child_expr.op)
    parent_precedence = operator_precedence(parent_expr.op)

    # Lower precedence always needs parens
    return true if child_precedence < parent_precedence

    # Same precedence on the right side of non-associative operators needs parens
    if child_precedence == parent_precedence && position == :right
      return !left_associative?(parent_expr.op)
    end

    false
  end

  # higher number = higher precedence
  def operator_precedence(op)
    case op
    when '||' then 1
    when '&&' then 2
    when '==', '!=' then 3
    when '<', '>', '<=', '>=' then 4
    when '+', '-' then 5
    when '*', '/' then 6
    else 0
    end
  end

  def left_associative?(op)
    # Most operators in Walrus are left-associative
    # Assignment would be right-associative, but we don't have assignment expressions
    true
  end
end
