# Add returns pass - Walrus 5: Returns
# Checks every function to ensure it ends with an explicit return statement.
# If a function doesn't end with a return, adds "return 0;" at the end.
#
# This makes implicit return behavior explicit, which helps with:
# - Code generation (knowing all functions have explicit returns)
# - Future compiler warnings/errors for missing returns
# - Consistency in function behavior
#
# Example transformation:
# Before:
#   func f(x) {
#       print 2 * x;
#   }
#
# After:
#   func f(x) {
#       print 2 * x;
#       return 0;
#   }

require_relative 'base'

module Walrus
  class EnsureAllFunctionsHaveExplicitReturns < AstTransformerBasedCompilerPass
    # Override function body transformation to add return if missing
    def transform_function(func, context)
      # Sanity check: type should be inferred by now
      unless func.type
        raise "COMPILER BUG: Function #{func.name} has no type at return injection"
      end

      body = func.body

      if body.empty? || !body.last.is_a?(Return)

        return_value = case func.type
                        when 'int'
                          IntegerLiteral.new(0).tap { |n| n.type = 'int' }
                        when 'float'
                          FloatLiteral.new(0.0).tap { |n| n.type = 'float' }
                        # when 'bool'
                        #   BooleanLiteral.new(false)
                        # when 'char'
                        #   CharacterLiteral.new(' ')
                        else
                          raise "Unknown return type: #{func.type}"
                        end
        return_node = Return.new(return_value)
        new_body = body + [return_node]
      else
        new_body = body
      end

      # Recursively process the function body to handle nested functions
      # (though Walrus doesn't support nested functions, we handle it for completeness)
      # Use transform() which handles arrays automatically
      Function.new(func.name, func.params, transform(new_body, context), type: func.type)
    end
  end
end
