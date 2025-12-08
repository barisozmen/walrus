# frozen_string_literal: true

require_relative 'base'
require_relative '../lib/jvm_type_mapper'
require_relative '../lib/jvm_bytecode_builder'

module Walrus
  # Converts stack-based IR instructions to JVM bytecode
  # Similar to GenerateLLVMCode but produces JVM bytecode instructions
  # Each BLOCK's instructions are transformed from abstract stack operations
  # to concrete JVM bytecode
  class GenerateJVMBytecode < AstTransformerBasedCompilerPass
    def before_transform(node, context)
      # Initialize global context (not local context - needs to persist)
      Walrus.context[:class_name] = 'WalrusProgram'
      Walrus.context[:jvm_builders] = {}

      context.merge(current_function: nil)
    end

    def transform_function(func, context)
      # Set current function for use by instruction handlers
      context = context.merge(current_function: func.name)

      # Create single builder for entire function
      builder = JVMBytecodeBuilder.new

      # Simulated stack and type map for entire function (NOT per block!)
      stack = []
      type_map = {}

      # Process each block
      func.body.each do |block|
        # Add label for this block
        builder.label(block.label)

        # Process instructions - stack and type_map carry over between blocks
        block.instructions.each do |instr|
          instr.get_jvm_bytecode(builder, stack, type_map, context)
        end
      end

      # Store builder in global context for use by FormatJVMClass
      Walrus.context[:jvm_builders][func.name] = builder

      func  # Return unchanged (bytecode stored in context)
    end
  end
end
