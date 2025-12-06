# infer_and_check_types.rb
#
# Type inference and checking pass for the Walrus language.
# Ensures all expressions have a known type (int, float, bool, char).
#
# Core insight: Type inference is scope resolution for types.
# - Tracks variable types in context (like ResolveVariableScopes tracks locals)
# - Validates type compatibility for operations
# - Reports type errors clearly
#
# Type rules:
# - Arithmetic ops: same type operands → same type result
# - Comparison ops: same type operands → bool result
# - NO mixed-type operations (strict type checking)
# - All expressions MUST have type after this pass

require_relative 'base'
require_relative '../compiler_error'

module Walrus
  class InferAndCheckTypes < AstTransformerBasedCompilerPass

    def before_transform(node, context)
      context.merge(
        var_types: {},        # name (String) => type (String)
        func_signatures: {},  # name (String) => { params: [types], return: type }
        expected_return_type: nil  # type (String) for validating returns
      )
    end

    # ===========================================================================
    # Phase 1: Literals - Assign implicit types
    # ===========================================================================

    def transform_integerliteral(node, context)
      node.tap { |n| n.type ||= 'int' }
    end

    def transform_floatliteral(node, context)
      node.tap { |n| n.type ||= 'float' }
    end

    def transform_characterliteral(node, context)
      node.tap { |n| n.type ||= 'char' }
    end

    def transform_stringliteral(node, context)
      node.tap { |n| n.type ||= 'str' }
    end

    def transform_gets(node, context)
      node.tap { |n| n.type ||= 'int' }
    end

    # ===========================================================================
    # Phase 2: Variable Declarations - Register types in context
    # ===========================================================================

    def transform_globalvardeclarationwithoutinit(node, context)
      # If type is specified, register it
      # If not, it will be inferred from the first assignment
      if node.type
        context[:var_types][node.name] = node.type
      end
      node
    end

    def transform_localvardeclarationwithoutinit(node, context)
      # If type is specified, register it
      if node.type
        context[:var_types][node.name] = node.type
      end

      # Always return node with inferred type from context (if available)
      inferred_type = context[:var_types][node.name]
      if inferred_type && inferred_type != node.type
        LocalVarDeclarationWithoutInit.new(node.name, type: inferred_type)
      else
        node
      end
    end

    def transform_globalvardeclarationwithinit(node, context)
      value = transform(node.value, context)
      inferred_type = value.type

      unless inferred_type
        raise CompilerError::TypeError.new(
          "Cannot infer type for #{node.name}",
          node.loc,
          hint: "Add a type annotation or ensure the initializer has a known type"
        )
      end

      # Validate if explicit type provided
      if node.type && node.type != inferred_type
        raise CompilerError::TypeError.new(
          "Cannot assign #{inferred_type} to #{node.name} (#{node.type})",
          node.loc,
          hint: "Change the type annotation to '#{inferred_type}' or convert the value"
        )
      end

      final_type = node.type || inferred_type
      context[:var_types][node.name] = final_type

      GlobalVarDeclarationWithInit.new(node.name, value, type: final_type)
    end

    def transform_localvardeclarationwithinit(node, context)
      value = transform(node.value, context)
      inferred_type = value.type

      unless inferred_type
        raise CompilerError::TypeError.new(
          "Cannot infer type for #{node.name}",
          node.loc,
          hint: "Add a type annotation or ensure the initializer has a known type"
        )
      end

      # Validate if explicit type provided
      if node.type && node.type != inferred_type
        raise CompilerError::TypeError.new(
          "Cannot assign #{inferred_type} to #{node.name} (#{node.type})",
          node.loc,
          hint: "Change the type annotation to '#{inferred_type}' or convert the value"
        )
      end

      final_type = node.type || inferred_type
      context[:var_types][node.name] = final_type

      LocalVarDeclarationWithInit.new(node.name, value, type: final_type)
    end

    # ===========================================================================
    # Phase 3: Name References - Lookup types from context
    # ===========================================================================

    def transform_globalname(node, context)
      type = context[:var_types][node.value]
      unless type
        raise CompilerError::TypeError.new("Global variable type cannot be determined: #{node.value}", node.loc)
      end
      node.tap { |n| n.type = type }
    end

    def transform_localname(node, context)
      type = context[:var_types][node.value]
      unless type
        raise CompilerError::TypeError.new(
          "Local variable type cannot be determined: #{node.value}",
          node.loc,
          hint: "Make the type explicit"
        )
      end
      node.tap { |n| n.type = type }
    end

    # ===========================================================================
    # Phase 4: Binary Operations - Type checking and result type inference
    # ===========================================================================

    def transform_binop(node, context)
      left = transform(node.left, context)
      right = transform(node.right, context)

      # Type compatibility check
      unless left.type == right.type
        hint = if (left.type == 'int' && right.type == 'float') || (left.type == 'float' && right.type == 'int')
                 "Convert both operands to the same type (either 'int' or 'float')"
               else
                 "Ensure both operands have the same type"
               end

        raise CompilerError::TypeError.new(
          "Type mismatch: cannot apply '#{node.op}' to #{left.type} and #{right.type}",
          node.loc,
          hint: hint
        )
      end

      # Determine result type based on operator
      result_type = if node.comparison?
        'bool'
      elsif node.arithmetic? || node.logical?
        left.type
      else
        raise CompilerError::CodegenError.new("Unknown operator: #{node.op}", node.loc)
      end

      new_node = BinOp.new(node.op, left, right, type: result_type)
      new_node.loc = node.loc  # Preserve location for error reporting
      new_node
    end

    # ===========================================================================
    # Phase 5: Unary Operations - Propagate operand type
    # ===========================================================================

    def transform_unaryop(node, context)
      operand = transform(node.operand, context)
      UnaryOp.new(node.op, operand, type: operand.type)
    end

    # ===========================================================================
    # Phase 6: Functions - Register signatures and validate body
    # ===========================================================================

    def transform_function(node, context)
      # Register function signature BEFORE body transformation
      # This allows recursive calls for explicit return types
      # Note: Functions with inferred return types cannot be recursive
      if node.type
        context[:func_signatures][node.name] = {
          params: node.params.map(&:type),
          return: node.type
        }
      end

      # Create function-scoped context
      func_context = context.merge(
        var_types: context[:var_types].dup,
        expected_return_type: node.type  # nil if inferring
      )

      # Register parameters in function scope
      node.params.each do |param|
        unless param.type
          raise CompilerError::TypeError.new(
            "Parameter #{param.name} missing type specifier",
            node.loc
          )
        end
        func_context[:var_types][param.name] = param.type
      end

      # Transform body (return values get typed here)
      body = transform_block(node.body, func_context)

      # TODO: refactor this later. This method became huge!
      # Infer return type if not specified
      if node.type.nil?
        return_types_and_locs = collect_return_types_from_transformed_body(body)

        if return_types_and_locs.empty?
          raise CompilerError::TypeError.new(
            "Function '#{node.name}' has no explicit return type and no return statements",
            node.loc,
            hint: "Add explicit return type or add return statement"
          )
        end

        # Extract just the types for comparison
        return_types = return_types_and_locs.map { |rt| rt[:type] }
        unique_types = return_types.uniq

        if unique_types.length > 1
          # Find the first conflicting return statement location
          first_type = return_types_and_locs.first[:type]
          conflicting = return_types_and_locs.find { |rt| rt[:type] != first_type }

          raise CompilerError::TypeError.new(
            "Function '#{node.name}' has inconsistent return types: #{unique_types.join(', ')}",
            conflicting[:loc],
            hint: "All return statements must return the same type"
          )
        end

        inferred_type = unique_types.first

        # Register function signature with inferred type
        context[:func_signatures][node.name] = {
          params: node.params.map(&:type),
          return: inferred_type
        }
      else
        inferred_type = node.type
      end

      # Post-process: update LocalVarDeclarationWithoutInit nodes with inferred types
      body = body.map do |stmt|
        update_declaration_types(stmt, func_context[:var_types])
      end

      Function.new(node.name, node.params, body, type: inferred_type)
    end

    # Recursively update LocalVarDeclarationWithoutInit nodes with inferred types
    def update_declaration_types(node, var_types)
      case node
      when LocalVarDeclarationWithoutInit
        inferred_type = var_types[node.name]
        if inferred_type && !node.type
          LocalVarDeclarationWithoutInit.new(node.name, type: inferred_type)
        else
          node
        end
      when MultipleStatements
        MultipleStatements.new(node.statements.map { |s| update_declaration_types(s, var_types) })
      else
        node
      end
    end

    # ===========================================================================
    # Helper: Collect return types from transformed function body
    # ===========================================================================

    # Collect return types and locations from transformed body (values already typed)
    def collect_return_types_from_transformed_body(statements)
      types_and_locs = []
      collect_return_types(statements, types_and_locs)
      types_and_locs
    end

    def collect_return_types(node, types_and_locs)
      case node
      when Return
        if node.value.type
          types_and_locs << { type: node.value.type, loc: node.loc }
        end
      when Array
        node.each { |stmt| collect_return_types(stmt, types_and_locs) }
      when If
        collect_return_types(node.then_block, types_and_locs)
        collect_return_types(node.else_block, types_and_locs) if node.else_block
      when While
        collect_return_types(node.body, types_and_locs)
      end
      types_and_locs
    end

    # ===========================================================================
    # Phase 7: Function Calls - Validate arguments and assign return type
    # ===========================================================================

    def transform_call(node, context)
      sig = context[:func_signatures][node.func]
      unless sig
        raise CompilerError::TypeError.new("Unknown function: #{node.func}", node.loc)
      end

      # Transform arguments
      args = node.args.map { |arg| transform(arg, context) }

      # Validate argument count
      unless args.length == sig[:params].length
        raise CompilerError::TypeError.new(
          "#{node.func} expects #{sig[:params].length} arguments, got #{args.length}",
          node.loc
        )
      end

      # Validate argument types
      args.each_with_index do |arg, i|
        unless arg.type == sig[:params][i]
          raise CompilerError::TypeError.new(
            "Argument #{i + 1} type mismatch: expected #{sig[:params][i]}, got #{arg.type}",
            node.loc
          )
        end
      end

      new_node = Call.new(node.func, args, type: sig[:return])
      new_node.loc = node.loc
      new_node
    end

    # ===========================================================================
    # Phase 8: Return Statements - Validate return type
    # ===========================================================================

    def transform_return(node, context)
      value = transform(node.value, context)
      expected = context[:expected_return_type]

      # Only validate if explicit type specified
      # For inferred types, validation happens in transform_function
      if expected && value.type != expected
        raise CompilerError::TypeError.new(
          "Return type mismatch: expected #{expected}, got #{value.type}",
          node.loc,
          hint: "Return a value of type '#{expected}' or change the function return type"
        )
      end

      new_node = Return.new(value)
      new_node.loc = node.loc if node.loc  # Preserve location
      new_node
    end

    # ===========================================================================
    # Phase 9: Assignments - Type compatibility check
    # ===========================================================================

    def transform_assignment(node, context)
      value = transform(node.value, context)

      # If variable doesn't have a type yet, infer it from the assignment
      var_name = node.name_ref.value
      if !context[:var_types][var_name]
        context[:var_types][var_name] = value.type
      end

      name_ref = transform(node.name_ref, context)

      unless name_ref.type == value.type
        raise CompilerError::TypeError.new(
          "Cannot assign #{value.type} to #{var_name} (#{name_ref.type})",
          node.loc,
          hint: "Convert the value to '#{name_ref.type}' or change the variable type"
        )
      end

      new_node = Assignment.new(name_ref, value)
      new_node.loc = node.loc
      new_node
    end

    # ===========================================================================
    # Phase 10: Control Flow - Validate condition types
    # ===========================================================================

    # def transform_if(node, context)
    #   condition = transform(node.condition, context)

    #   unless condition.type == 'bool'
    #     raise_type_error("If condition must be bool, got #{condition.type}")
    #   end

    #   If.new(
    #     condition,
    #     transform_block(node.then_block, context),
    #     transform_block(node.else_block, context)
    #   )
    # end

    # def transform_while(node, context)
    #   condition = transform(node.condition, context)

    #   unless condition.type == 'bool'
    #     raise_type_error("While condition must be bool, got #{condition.type}")
    #   end

    #   While.new(condition, transform_block(node.body, context))
    # end

    # ===========================================================================
    # Phase 11: Other Statements - Pass through with transformation
    # ===========================================================================

    # def transform_print(node, context)
    #   value = transform(node.value, context)
    #   Print.new(value)
    # end

    # def transform_exprstatement(node, context)
    #   value = transform(node.value, context)
    #   ExprStatement.new(value)
    # end

    private

    # Transform block of statements sequentially
    # Similar to ResolveVariableScopes#transform_block
    def transform_block(statements, context)
      statements.map { |stmt| transform(stmt, context) }
    end

  end
end
