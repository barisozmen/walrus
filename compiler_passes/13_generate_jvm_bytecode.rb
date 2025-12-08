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
      context.merge(
        class_name: 'WalrusProgram',
        jvm_builders: {},  # function_name => JVMBytecodeBuilder
        current_function: nil
      )
    end

    def transform_function(func, context)
      # Set current function for use by instruction handlers
      context = context.merge(current_function: func.name)

      # Create single builder for entire function
      builder = JVMBytecodeBuilder.new

      # Process each block
      func.body.each do |block|
        # Add label for this block
        builder.label(block.label)

        # Process instructions with simulated stack
        stack = []
        type_map = {}

        block.instructions.each do |instr|
          instr.get_jvm_bytecode(builder, stack, type_map, context)
        end
      end

      # Store builder in context for use by FormatJVMClass
      context[:jvm_builders][func.name] = builder

      func  # Return unchanged (bytecode stored in context)
    end
  end
end
