require_relative 'base'

module Walrus
  # Adds LLVM entry blocks to functions for proper argument handling
  #
  # Function arguments in Walrus are passed by value and require memory locations
  # for mutation. This pass transforms each function by:
  #
  # 1. Renaming parameters (x → .arg_x) in the function signature
  # 2. Creating an "entry" block that:
  #    - Allocates stack memory for each parameter
  #    - Stores argument values into allocated memory
  #    - Branches to the first original block
  #
  # Example transformation:
  #   func add(x, y) {
  #     L1:
  #       LLVM(%r = alloca i32)
  #       LLVM(%.1 = load i32, i32* %x)    // Error: %x not allocated!
  #       ...
  #   }
  #
  # becomes:
  #   func add(.arg_x, .arg_y) {
  #     entry:
  #       LLVM(%x = alloca i32)
  #       LLVM(store i32 %.arg_x, i32* %x)
  #       LLVM(%y = alloca i32)
  #       LLVM(store i32 %.arg_y, i32* %y)
  #       LLVM(br label %L1)
  #     L1:
  #       LLVM(%r = alloca i32)
  #       LLVM(%.1 = load i32, i32* %x)    // Now %x exists!
  #       ...
  #   }
  class AddLlvmEntryBlocks < AstTransformerBasedCompilerPass
    def transform_function(func, context)
      # 1. Rename parameters: x → .arg_x (as Parameter objects)
      renamed_params = func.params.map { |param| Parameter.new(".arg_#{param.name}", type: param.type) }

      # 2. Build entry block instructions (pass full params to preserve types)
      entry_instructions = build_entry_instructions(func.params, func.body.first.label)

      # 3. Create entry block
      entry_block = BLOCK.new("entry", entry_instructions)

      # 4. Return new function with entry block prepended
      Function.new(func.name, renamed_params, [entry_block] + func.body, type: func.type)
    end

    private

    def build_entry_instructions(params, first_block_label)
      instructions = []

      # For each parameter, allocate memory and store the argument value
      params.each do |param|
        llvm_type = param.type == 'float' ? 'double' : 'i32'

        # Allocate memory: %x = alloca double (or i32)
        instructions << LLVM.new("%#{param.name} = alloca #{llvm_type}")
        # Store argument value: store double %.arg_x, double* %x
        instructions << LLVM.new("store #{llvm_type} %.arg_#{param.name}, #{llvm_type}* %#{param.name}")
      end

      # Branch to first block: br label %L1
      instructions << LLVM.new("br label %#{first_block_label}")

      instructions
    end
  end
end
