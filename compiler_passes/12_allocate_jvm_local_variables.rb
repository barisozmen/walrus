# frozen_string_literal: true

require_relative 'base'
require_relative '../lib/jvm_type_mapper'

module Walrus
  # Allocates JVM local variable slots for function parameters and locals
  # Unlike LLVM (which needs explicit alloca), JVM has built-in local variable table
  #
  # Slot allocation:
  # - Parameters occupy slots 0, 1, 2, ... (in order)
  # - Doubles/longs take 2 slots
  # - Local variables occupy subsequent slots
  #
  # Example:
  #   func add(x int, y float, z int) {
  #     var temp float;
  #   }
  # Slot map:
  #   x -> 0 (int, 1 slot)
  #   y -> 1 (float/double, 2 slots: 1 and 2)
  #   z -> 3 (int, 1 slot)
  #   temp -> 4 (float/double, 2 slots: 4 and 5)
  # Max locals = 6
  class AllocateJVMLocalVariables < AstTransformerBasedCompilerPass
    def before_transform(node, context)
      context.merge(
        local_var_maps: {},  # function_name => { var_name => slot_index }
        max_locals_map: {}   # function_name => max_locals
      )
    end

    def transform_function(func, context)
      local_var_map = {}
      next_slot = 0

      # Allocate parameter slots
      func.params.each do |param|
        local_var_map[param.name] = next_slot
        next_slot += JVMTypeMapper.slot_width(param.type)
      end

      # Scan blocks for LOCAL instructions (variable declarations)
      declared_vars = Set.new
      func.body.each do |block|
        block.instructions.each do |instr|
          if instr.is_a?(LOCAL) && !declared_vars.include?(instr.name)
            local_var_map[instr.name] = next_slot
            next_slot += JVMTypeMapper.slot_width(instr.type)
            declared_vars.add(instr.name)
          end
        end
      end

      # Store in context for use by GenerateJVMBytecode
      context[:local_var_maps][func.name] = local_var_map
      context[:max_locals_map][func.name] = next_slot

      func
    end
  end
end
