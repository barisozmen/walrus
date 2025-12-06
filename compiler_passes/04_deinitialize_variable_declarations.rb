# De-initialization pass.
# Splits variable declarations with initialization into two separate statements:
# 1. A variable declaration (VarDeclarationWithoutInit) without a value
# 2. An assignment statement
#
# Example transformation:
#   var x = 10;
#   =>
#   var x;
#   x = 10;

require_relative 'base'

module Walrus
  class DeinitializeVariableDeclarations < AstTransformerBasedCompilerPass
    def transform_vardeclarationwithinit(stmt, context)
      MultipleStatements.new([
        VarDeclarationWithoutInit.new(stmt.name, type: stmt.type),
        Assignment.new(Name.new(stmt.name), transform(stmt.value, context))
      ])
    end
  end
end
