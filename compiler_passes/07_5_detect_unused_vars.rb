# detect_unused_vars.rb
#
# Detects unused variables and emits warnings.
# This pass focuses solely on tracking variable declarations and usage.
#
# Separated from type inference pass to maintain Single Responsibility Principle:
# - Type inference: determines types (required for compilation)
# - Unused variable detection: code quality warnings (optional)

require_relative 'base'
require_relative '../compiler_error'

module Walrus
  class DetectUnusedVars < AstTransformerBasedCompilerPass

    def before_transform(node, context)
      context.merge(
        var_declarations: {},  # name (String) => loc (SourceLocation)
        var_usage: {}          # name (String) => [locs] (Array<SourceLocation>)
      )
    end

    # ===========================================================================
    # Variable Declarations - Track declaration locations
    # ===========================================================================

    def transform_globalvardeclarationwithoutinit(node, context)
      context[:var_declarations][node.name] = node.loc
      node
    end

    def transform_localvardeclarationwithoutinit(node, context)
      context[:var_declarations][node.name] = node.loc
      node
    end

    def transform_globalvardeclarationwithinit(node, context)
      context[:var_declarations][node.name] = node.loc
      node
    end

    def transform_localvardeclarationwithinit(node, context)
      context[:var_declarations][node.name] = node.loc
      node
    end

    # ===========================================================================
    # Variable References - Track usage locations
    # ===========================================================================

    def transform_globalname(node, context)
      # Track variable usage (but not assignment targets)
      unless context[:in_assignment_target]
        context[:var_usage][node.value] ||= []
        context[:var_usage][node.value] << node.loc
      end
      node
    end

    def transform_localname(node, context)
      # Track variable usage (but not assignment targets)
      unless context[:in_assignment_target]
        context[:var_usage][node.value] ||= []
        context[:var_usage][node.value] << node.loc
      end
      node
    end

    # ===========================================================================
    # Assignments - Mark assignment targets to avoid false positives
    # ===========================================================================

    def transform_assignment(node, context)
      # Mark that we're transforming an assignment target (not a usage)
      assignment_context = context.merge(in_assignment_target: true)
      name_ref = transform(node.name_ref, assignment_context)

      # Transform value normally (may contain variable usages)
      value = transform(node.value, context)

      new_node = Assignment.new(name_ref, value)
      new_node.loc = node.loc
      new_node
    end

    # ===========================================================================
    # Post-processing - Emit warnings for unused variables
    # ===========================================================================

    def after_transform(input, result, context)
      context[:var_declarations].each do |name, loc|
        unless context[:var_usage][name]
          # Only add warnings if context[:warnings] exists (during full compilation)
          if Walrus.context[:warnings]
            Walrus.context[:warnings] << CompilerWarning.new(
              "Unused variable '#{name}'",
              loc,
              phase: :semantic
            )
          end
        end
      end
      result
    end

  end
end
