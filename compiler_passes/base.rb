require_relative '../model'

module Walrus
  module AstTransformer
    # Hook: Override to set up initial context
    def before_transform(node, context)
      context
    end

    # Hook: Override to process final result
    def after_transform(node, result, context)
      result
    end

    def transform(node, context)
      # Handle the edge case ofarrays - transform each element and flatten MultipleStatements
      if node.is_a?(Array)
        return node.flat_map do |item|
          result = transform(item, context)
          result.is_a?(MultipleStatements) ? result.statements : [result]
        end
      end

      # If subclasses implement a specific transform method for this node class, we'll use it
      if self.respond_to?("transform_#{node.class.name.downcase}", true)
        return send("transform_#{node.class.name.downcase}", node, context)
      end

      if !node.respond_to?(:attr_names)
        return node
      end

      # Default transformation: reconstruct node with transformed children
      new_node = node.class.new(
        *node.attr_names.map { |name|
           transform(node.instance_variable_get("@#{name}"), context)
        },
      )

      # Preserve type attribute if present (not part of children)
      new_node.type = node.type if node.respond_to?(:type)

      # Preserve param_types for CALL instructions
      new_node.param_types = node.param_types if node.respond_to?(:param_types)

      # Preserve source location for error reporting
      new_node.loc = node.loc if node.respond_to?(:loc) && node.loc

      new_node
    end
  end

  class CompilerPass
    def run(input)
      raise NotImplementedError, "#{self.class} must implement run(input)"
    end
  end

  class AstTransformerBasedCompilerPass < CompilerPass
    include AstTransformer

    def run(input)
      context = before_transform(input, {})
      result = transform(input, context)
      after_transform(input, result, context)
    end
  end
end