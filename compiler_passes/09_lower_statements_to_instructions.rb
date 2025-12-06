require_relative 'base'

module Walrus
  class LowerStatementsToInstructions < AstTransformerBasedCompilerPass
    # Print: expr.instructions + PRINT
    def transform_print(node, context)
      STATEMENT.new(node.value.instructions + [PRINT.new])
    end

    # Return: expr.instructions + RETURN
    def transform_return(node, context)
      STATEMENT.new(node.value.instructions + [RETURN.new(type: node.value.type)])
    end

    # Break: keep as-is (handled in control flow flattening)
    def transform_break(node, context)
      node
    end

    # Continue: keep as-is (handled in control flow flattening)
    def transform_continue(node, context)
      node
    end

    # ExprStatement: evaluate expression, discard result
    def transform_exprstatement(node, context)
      STATEMENT.new(node.value.instructions)
    end

    # Assignment: expr.instructions + STORE_X(name)
    def transform_assignment(node, context)
      name = node.name_ref.value
      store = node.name_ref.is_a?(GlobalName) ?
        STORE_GLOBAL.new(name, type: node.value.type) : STORE_LOCAL.new(name, type: node.value.type)

      STATEMENT.new(node.value.instructions + [store])
    end

    # Local var declaration with init: LOCAL(name) + expr.instructions + STORE_LOCAL(name)
    def transform_localvardeclarationwithinit(node, context)
      STATEMENT.new([LOCAL.new(node.name, type: node.type)] + node.value.instructions + [STORE_LOCAL.new(node.name, type: node.type)])
    end

    # Local var declaration without init: LOCAL(name)
    def transform_localvardeclarationwithoutinit(node, context)
      STATEMENT.new([LOCAL.new(node.name, type: node.type)])
    end

    # Global var declaration with init: expr.instructions + STORE_GLOBAL(name)
    def transform_globalvardeclarationwithinit(node, context)
      STATEMENT.new(node.value.instructions + [STORE_GLOBAL.new(node.name, type: node.value.type)])
    end

    # Global var declaration without init: nothing (handled elsewhere)
    def transform_globalvardeclarationwithoutinit(node, context)
      node
    end

    # If/While: keep structure, transform condition and body
    def transform_if(node, context)
      If.new(
        node.condition,
        transform(node.then_block, context),
        transform(node.else_block, context)
      )
    end

    def transform_while(node, context)
      While.new(node.condition, transform(node.body, context))
    end
  end
end
