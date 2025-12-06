require_relative 'base'
require_relative '../lib/type_mapper'
require_relative '../compile/context'

module Walrus
  # Converts stack-based instructions to LLVM SSA instructions
  # Each BLOCK's instructions are transformed from abstract stack operations
  # to concrete LLVM three-address code
  class GenerateLLVMCode < AstTransformerBasedCompilerPass
    # Reset once at start
    def before_transform(node, context)
      LLVMRegisterNameGenerator.reset
      context
    end

    # Transform a BLOCK by converting its instructions to LLVM
    def transform_block(node, context)
      BLOCK.new(node.label, generate_llvm_instructions(node))
    end

    private

    # Core transformation: simulate stack machine, generate LLVM instructions
    def generate_llvm_instructions(block)
      stack = []
      type_map = {}  # Track types of registers
      ops = []

      block.instructions.each do |instr|
        result = instr.get_llvm_code(stack, type_map)
        ops << result if result  # nil = no instruction to emit
      end
      ops
    end
  end
end
