require_relative 'base'

module Walrus
  # Label generator for unique block labels
  class LabelGenerator
    def initialize
      @counter = 0
    end

    def gen_label
      label = "L#{@counter}"
      @counter += 1
      label
    end
  end

  # Merges adjacent STATEMENT nodes into labeled BLOCK nodes
  # Each BLOCK represents a basic block - a sequence of instructions with no control flow
  class MergeStatementsIntoBasicBlocks < AstTransformerBasedCompilerPass
    def before_transform(node, context)
      context.merge(label_gen: LabelGenerator.new)
    end

    # Transform statement lists - merge adjacent STATEMENTs into BLOCKs
    def transform_statement_list(statements, context)
      return [] if statements.nil? || statements.empty?

      result = []
      current_block_instructions = []

      statements.each do |stmt|
        if stmt.is_a?(STATEMENT)
          # Accumulate instructions from STATEMENT nodes
          current_block_instructions.concat(stmt.instructions)
        else
          # Flush accumulated instructions as a BLOCK
          if !current_block_instructions.empty?
            result << BLOCK.new(context[:label_gen].gen_label, current_block_instructions)
            current_block_instructions = []
          end

          # Transform and add the non-STATEMENT node
          result << transform(stmt, context)
        end
      end

      # Flush remaining instructions
      if !current_block_instructions.empty?
        result << BLOCK.new(context[:label_gen].gen_label, current_block_instructions)
      end

      result
    end

    # Override array transformation to handle statement lists
    def transform(node, context)
      if node.is_a?(Array)
        return transform_statement_list(node, context)
      end

      # Default transformation via parent
      super(node, context)
    end

    # Function: transform body
    def transform_function(node, context)
      Function.new(
        node.name,
        node.params,
        transform_statement_list(node.body, context),
        type: node.type
      )
    end

    # If: transform then_block and else_block
    def transform_if(node, context)
      If.new(
        transform(node.condition, context),
        transform_statement_list(node.then_block, context),
        transform_statement_list(node.else_block, context)
      )
    end

    # While: transform body
    def transform_while(node, context)
      While.new(
        transform(node.condition, context),
        transform_statement_list(node.body, context)
      )
    end

    # Program: transform statements
    def transform_program(node, context)
      Program.new(transform_statement_list(node.statements, context))
    end
  end
end
