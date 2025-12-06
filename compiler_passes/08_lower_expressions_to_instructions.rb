
require_relative 'base'
require_relative '../compiler_error'
require_relative '../compile/context'

module Walrus
  class LowerExpressionsToInstructions < AstTransformerBasedCompilerPass
    # Literals: push value onto stack
    def transform_integerliteral(node, context)
      EXPR.new([PUSH.new(node.value)], type: 'int')
    end

    def transform_floatliteral(node, context)
      EXPR.new([PUSH.new(node.value)], type: 'float')
    end

    def transform_characterliteral(node, context)
      EXPR.new([PUSH.new(node.value.ord, type: 'char')], type: 'char')
    end

    def transform_stringliteral(node, context)
      # Store string in global context for later emission
      Walrus.context[:string_counter] ||= 0
      label = "@.str.#{Walrus.context[:string_counter]}"
      Walrus.context[:string_counter] += 1

      Walrus.context[:global_strings] ||= {}
      Walrus.context[:global_strings][label] = node.value

      EXPR.new([PUSH.new(label, type: 'str')], type: 'str')
    end

    def transform_gets(node, context)
      EXPR.new([GETS.new], type: 'int')
    end

    # Variables: load from memory onto stack
    def transform_localname(node, context)
      EXPR.new([LOAD_LOCAL.new(node.value, type: node.type)], type: node.type)
    end

    def transform_globalname(node, context)
      EXPR.new([LOAD_GLOBAL.new(node.value, type: node.type)], type: node.type)
    end

    # Binary operations: left, right, operator
    def transform_binop(node, context)
      left = transform(node.left, context)
      right = transform(node.right, context)

      instruction = case node.op
      when '+' then ADD.new
      when '-' then SUB.new
      when '*' then MUL.new
      when '/' then DIV.new
      when '<' then LT.new
      when '>' then GT.new
      when '<=' then LE.new
      when '>=' then GE.new
      when '==' then EQ.new
      when '!=' then NE.new
      when '&&' then AND.new
      when '||' then OR.new
      else raise CompilerError::CodegenError.new("Unknown operator: #{node.op}", node.loc)
      end

      EXPR.flatten(left, right, instruction).tap { |e| e.type = node.type }
    end

    # Unary operations: operand, operator
    def transform_unaryop(node, context)
      operand = transform(node.operand, context)

      instruction = case node.op
      when '-' then NEG.new
      when '!' then NOT.new
      else raise CompilerError::CodegenError.new("Unknown operator: #{node.op}", node.loc)
      end

      EXPR.flatten(operand, instruction).tap { |e| e.type = node.type }
    end

    # Function calls: args, call
    def transform_call(node, context)
      arg_exprs = node.args.map { |arg| transform(arg, context) }

      call = CALL.new(node.func, node.args.length, type: node.type)
      call.param_types = node.args.map(&:type)

      EXPR.flatten(*arg_exprs, call).tap { |e| e.type = node.type }
    end

    # Assignment: keep name_ref as-is (lvalue), only transform value (rvalue)
    def transform_assignment(node, context)
      Assignment.new(node.name_ref, transform(node.value, context), type: node.value.type)
    end
  end
end
