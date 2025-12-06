require_relative 'base'
require_relative '../compiler_error'

module Walrus
  # Compiler pass that folds constant expressions at compile time
  # Evaluates binary and unary operations on integer and float literals
  class FoldConstants < AstTransformerBasedCompilerPass
    def transform_binop(expr, context)
      left_operand = transform(expr.left, context)
      right_operand = transform(expr.right, context)

      is_int_op = left_operand.is_a?(IntegerLiteral) && right_operand.is_a?(IntegerLiteral)
      is_float_op = left_operand.is_a?(FloatLiteral) && right_operand.is_a?(FloatLiteral)

      unless is_int_op || is_float_op
        new_node = BinOp.new(expr.op, left_operand, right_operand, type: expr.type)
        new_node.loc = expr.loc
        return new_node
      end

      left_val = left_operand.value
      right_val = right_operand.value

      result = case expr.op
               when '+' then left_val + right_val
               when '-' then left_val - right_val
               when '*' then left_val * right_val
               when '/' then left_val / right_val
               when '<' then left_val < right_val ? 1 : 0
               when '>' then left_val > right_val ? 1 : 0
               when '<=' then left_val <= right_val ? 1 : 0
               when '>=' then left_val >= right_val ? 1 : 0
               when '==' then left_val == right_val ? 1 : 0
               when '!=' then left_val != right_val ? 1 : 0
               else
                 raise CompilerError::CodegenError.new("Unknown operator: #{expr.op}", expr.loc)
               end

      literal = left_operand.is_a?(FloatLiteral) ? FloatLiteral.new(result) : IntegerLiteral.new(result)
      literal.type = expr.type if expr.type
      literal
    end

    def transform_unaryop(expr, context)
      operand_val = transform(expr.operand, context)

      return UnaryOp.new(expr.op, operand_val, type: expr.type) unless operand_val.is_a?(IntegerLiteral) || operand_val.is_a?(FloatLiteral)

      result = case expr.op
               when '-' then -operand_val.value
               when '!' then operand_val.value == 0 ? 1 : 0
               else operand_val.value
               end

      literal = operand_val.is_a?(FloatLiteral) ? FloatLiteral.new(result) : IntegerLiteral.new(result)
      literal.type = expr.type if expr.type
      literal
    end

    def transform_floatliteral(node, context)
      node
    end
  end
end
