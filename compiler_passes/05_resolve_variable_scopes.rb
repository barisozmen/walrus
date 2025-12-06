# Scope resolution pass.
# Transforms variable declarations and references to explicitly mark them
# as global or local scope.
#
# Transformation:
#   VarDeclarationWithoutInit -> GlobalVarDeclarationWithoutInit or LocalVarDeclarationWithoutInit
#   VarDeclarationWithInit -> GlobalVarDeclarationWithInit or LocalVarDeclarationWithInit
#   Name -> GlobalName or LocalName
#
# Scoping rules:
# - Top-level declarations (outside any blocks) are global
# - Function parameters and function-body declarations are local
# - Functions reset local scope
# - If/while blocks use local scope for declarations, but can access outer scope variables

require_relative 'base'

module Walrus
  class ResolveVariableScopes < AstTransformerBasedCompilerPass
    def before_transform(node, context)
      context.merge(locals: Set.new, scope: :global)
    end

    def transform_program(node, context)
      Program.new(transform_block(node.statements, context))
    end

    def transform_vardeclarationwithoutinit(node, context)
      context[:scope] == :global ?
        GlobalVarDeclarationWithoutInit.new(node.name, type: node.type) :
        LocalVarDeclarationWithoutInit.new(node.name, type: node.type)
    end

    def transform_vardeclarationwithinit(node, context)
      value = transform(node.value, context)
      context[:scope] == :global ?
        GlobalVarDeclarationWithInit.new(node.name, value, type: node.type) :
        LocalVarDeclarationWithInit.new(node.name, value, type: node.type)
    end

    def transform_name(node, context)
      new_node = context[:locals].include?(node.value) ?
        LocalName.new(node.value) :
        GlobalName.new(node.value)
      new_node.type = node.type if node.type
      new_node.loc = node.loc if node.loc
      new_node
    end

    def transform_if(node, context)
      local_ctx = context.merge(scope: :local)
      If.new(
        transform(node.condition, context),
        transform_block(node.then_block, local_ctx),
        transform_block(node.else_block, local_ctx)
      )
    end

    def transform_while(node, context)
      While.new(
        transform(node.condition, context),
        transform_block(node.body, context.merge(scope: :local))
      )
    end

    def transform_function(node, context)
      Function.new(
        node.name,
        node.params,
        transform_block(
          node.body,
          context.merge(locals: Set.new(node.params.map(&:name)), scope: :local)
        ),
        type: node.type
      )
    end

    private

    # Transform statements sequentially, accumulating locals as declarations are encountered
    def transform_block(statements, context)
      known_locals = context[:locals]

      statements.map do |stmt|
        transformed = transform(stmt, context.merge(locals: known_locals))
        known_locals |= locals_declared_in(transformed)
        transformed
      end
    end

    # What local variables are declared in this statement (including nested blocks)?
    def locals_declared_in(stmt)
      case stmt
      when LocalVarDeclarationWithoutInit, LocalVarDeclarationWithInit
        Set[stmt.name]
      when If
        locals_in(stmt.then_block) | locals_in(stmt.else_block)
      when While
        locals_in(stmt.body)
      else
        Set.new
      end
    end

    def locals_in(statements)
      statements.flat_map { |s| locals_declared_in(s).to_a }.to_set
    end
  end
end
