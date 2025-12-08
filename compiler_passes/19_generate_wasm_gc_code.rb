require_relative 'base'
require_relative '../lib/type_mapper_wasm'
require_relative '../lib/wasm_local_generator'
require_relative '../compile/context'

module Walrus
  # Converts stack-based instructions to WasmGC instructions
  #
  # Unlike LLVM which requires SSA (Static Single Assignment), WasmGC is naturally
  # stack-based, making the translation more straightforward. Each abstract instruction
  # maps to one or more WasmGC instructions.
  #
  # WasmGC instruction format uses S-expressions:
  #   (i32.add)           - add two i32 values from stack
  #   (local.get $x)      - push local variable onto stack
  #   (local.set $x)      - pop stack into local variable
  #   (global.get $x)     - push global variable onto stack
  #   (global.set $x)     - pop stack into global variable
  #   (call $func)        - call function
  #   (br $label)         - branch to label
  #   (br_if $label)      - conditional branch
  #
  class GenerateWasmGCCode < AstTransformerBasedCompilerPass
    # Reset generators at start of compilation
    def before_transform(node, context)
      context.merge(
        wasm_globals: WasmGlobalRegistry.new,
        wasm_locals: nil,  # Set per-function
        type_stack: []     # Track types on the value stack
      )
    end

    # Transform a function - set up locals generator
    def transform_function(node, context)
      locals_gen = WasmLocalGenerator.new

      # Register parameters
      node.params.each do |param|
        locals_gen.add_param(param.name, param.type)
      end

      # Transform body with locals context
      func_context = context.merge(
        wasm_locals: locals_gen,
        type_stack: [],
        current_function_type: node.type
      )

      # Collect locals from the body first (pre-scan for LOCAL instructions)
      collect_locals(node.body, locals_gen)

      # Transform each block
      transformed_body = node.body.map do |block|
        transform(block, func_context)
      end

      # Create new function with transformed body and locals info
      func = Function.new(node.name, node.params, transformed_body)
      func.type = node.type
      func.instance_variable_set(:@wasm_locals, locals_gen)
      func
    end

    # Transform a BLOCK by converting its instructions to WasmGC
    def transform_block(node, context)
      BLOCK.new(node.label, generate_wasm_instructions(node, context))
    end

    private

    # Pre-scan to collect all local variable declarations
    def collect_locals(body, locals_gen)
      body.each do |block|
        next unless block.is_a?(BLOCK)
        block.instructions.each do |instr|
          if instr.is_a?(LOCAL)
            locals_gen.add_local(instr.name, instr.type)
          end
        end
      end
    end

    # Core transformation: convert abstract instructions to WasmGC instructions
    def generate_wasm_instructions(block, context)
      type_stack = []  # Track types of values on the stack
      ops = []

      block.instructions.each do |instr|
        result = instruction_to_wasm(instr, type_stack, context)
        if result.is_a?(Array)
          ops.concat(result)
        elsif result
          ops << result
        end
      end

      ops
    end

    # Convert a single instruction to WasmGC
    def instruction_to_wasm(instr, type_stack, context)
      case instr
      when PUSH
        push_to_wasm(instr, type_stack, context)
      when ADD, SUB, MUL, DIV
        arithmetic_to_wasm(instr, type_stack)
      when LT, GT, LE, GE, EQ, NE
        comparison_to_wasm(instr, type_stack)
      when NEG
        neg_to_wasm(instr, type_stack)
      when NOT
        not_to_wasm(instr, type_stack)
      when LOAD_LOCAL
        load_local_to_wasm(instr, type_stack, context)
      when LOAD_GLOBAL
        load_global_to_wasm(instr, type_stack, context)
      when STORE_LOCAL
        store_local_to_wasm(instr, type_stack, context)
      when STORE_GLOBAL
        store_global_to_wasm(instr, type_stack, context)
      when LOCAL
        # LOCAL declarations are handled at function level, emit nothing here
        nil
      when CALL
        call_to_wasm(instr, type_stack, context)
      when PRINT
        print_to_wasm(instr, type_stack, context)
      when GETS
        gets_to_wasm(instr, type_stack)
      when RETURN
        return_to_wasm(instr, type_stack, context)
      when GOTO
        goto_to_wasm(instr, type_stack)
      when CBRANCH
        cbranch_to_wasm(instr, type_stack)
      when LLVM
        # Skip LLVM-specific instructions
        nil
      else
        raise "Unknown instruction type: #{instr.class}"
      end
    end

    # PUSH - push a literal value onto the stack
    def push_to_wasm(instr, type_stack, context)
      wasm_type = TypeMapperWasm.to_wasm(instr.type || 'int')
      type_stack.push(wasm_type)

      if instr.type == 'str'
        # String handling - for now, push string index
        # TODO: Implement proper string handling with WasmGC string type
        WASM.new("i32.const 0", "String placeholder")
      elsif instr.type == 'float' || instr.value.to_s.include?('.')
        WASM.new("f64.const #{instr.value}")
      elsif instr.type == 'char'
        # Character as integer code point
        char_value = instr.value.is_a?(String) ? instr.value.ord : instr.value
        WASM.new("i32.const #{char_value}")
      else
        WASM.new("i32.const #{instr.value}")
      end
    end

    # Arithmetic operations
    def arithmetic_to_wasm(instr, type_stack)
      # Pop two operands, push result
      right_type = type_stack.pop
      left_type = type_stack.pop
      result_type = (left_type == 'f64' || right_type == 'f64') ? 'f64' : 'i32'
      type_stack.push(result_type)

      op = case instr
           when ADD then 'add'
           when SUB then 'sub'
           when MUL then 'mul'
           when DIV then result_type == 'f64' ? 'div' : 'div_s'
           end

      WASM.new("#{result_type}.#{op}")
    end

    # Comparison operations
    def comparison_to_wasm(instr, type_stack)
      right_type = type_stack.pop
      left_type = type_stack.pop
      is_float = (left_type == 'f64' || right_type == 'f64')
      type_stack.push('i32')  # Comparisons always return i32 (0 or 1)

      op = case instr
           when LT then is_float ? 'f64.lt' : 'i32.lt_s'
           when GT then is_float ? 'f64.gt' : 'i32.gt_s'
           when LE then is_float ? 'f64.le' : 'i32.le_s'
           when GE then is_float ? 'f64.ge' : 'i32.ge_s'
           when EQ then is_float ? 'f64.eq' : 'i32.eq'
           when NE then is_float ? 'f64.ne' : 'i32.ne'
           end

      WASM.new(op)
    end

    # Unary negation
    def neg_to_wasm(instr, type_stack)
      operand_type = type_stack.pop
      type_stack.push(operand_type)

      if operand_type == 'f64'
        WASM.new("f64.neg")
      else
        # For integers: negate by subtracting from 0
        # Push 0, then the value, then subtract
        # But we already have the value on stack, so we need a different approach
        # Use: (i32.const 0) (i32.sub) but stack order matters
        # Actually: val is on stack, we need 0 - val
        # So: swap stack order somehow... or use a local
        # Simpler: multiply by -1 or use (i32.sub (i32.const 0) val)
        # In Wasm, we'd need to restructure. For now, use mul by -1
        [
          WASM.new("i32.const -1"),
          WASM.new("i32.mul")
        ]
      end
    end

    # Logical NOT
    def not_to_wasm(instr, type_stack)
      type_stack.pop
      type_stack.push('i32')
      WASM.new("i32.eqz")  # NOT is equivalent to "equals zero"
    end

    # Load local variable
    def load_local_to_wasm(instr, type_stack, context)
      locals_gen = context[:wasm_locals]
      wasm_type = locals_gen&.type_of(instr.name) || TypeMapperWasm.to_wasm(instr.type || 'int')
      type_stack.push(wasm_type)
      WASM.new("local.get $#{instr.name}")
    end

    # Load global variable
    def load_global_to_wasm(instr, type_stack, context)
      wasm_type = TypeMapperWasm.to_wasm(instr.type || 'int')
      type_stack.push(wasm_type)
      WASM.new("global.get $#{instr.name}")
    end

    # Store to local variable
    def store_local_to_wasm(instr, type_stack, context)
      type_stack.pop
      WASM.new("local.set $#{instr.name}")
    end

    # Store to global variable
    def store_global_to_wasm(instr, type_stack, context)
      type_stack.pop
      WASM.new("global.set $#{instr.name}")
    end

    # Function call
    def call_to_wasm(instr, type_stack, context)
      # Pop arguments from type stack
      instr.nargs.times { type_stack.pop }

      # Push return type
      return_type = TypeMapperWasm.to_wasm(instr.type || 'int')
      type_stack.push(return_type)

      WASM.new("call $#{instr.name}")
    end

    # Print - calls runtime function
    def print_to_wasm(instr, type_stack, context)
      value_type = type_stack.pop

      func_name = case value_type
                  when 'f64' then '$_print_float'
                  when 'i32' then '$_print_int'
                  else '$_print_int'
                  end

      # Call print function, push dummy return value
      type_stack.push('i32')
      [
        WASM.new("call #{func_name}"),
        WASM.new("drop")  # Discard the return value
      ]
    end

    # Gets - read input
    def gets_to_wasm(instr, type_stack)
      type_stack.push('i32')
      WASM.new("call $_gets_int")
    end

    # Return from function
    def return_to_wasm(instr, type_stack, context)
      type_stack.pop
      WASM.new("return")
    end

    # Unconditional branch (will be transformed in control flow pass)
    def goto_to_wasm(instr, type_stack)
      # GOTO will be transformed to proper br in the control flow pass
      # For now, emit a marker instruction
      WASM_GOTO.new(instr.label)
    end

    # Conditional branch (will be transformed in control flow pass)
    def cbranch_to_wasm(instr, type_stack)
      # CBRANCH will be transformed in the control flow pass
      # For now, emit a marker instruction
      type_stack.pop  # Condition value
      WASM_CBRANCH.new(instr.true_label, instr.false_label)
    end
  end
end

# WasmGC instruction holder (similar to LLVM class)
class WASM < INSTRUCTION
  attr_reader :op
  attr_accessor :comment

  def initialize(op, comment = nil)
    @op = op
    @comment = comment
  end

  def ==(other)
    return false unless other.is_a?(WASM)
    @op == other.op
  end

  def hash
    [self.class, @op].hash
  end

  alias_method :eql?, :==
end

# Marker for GOTO - will be transformed in control flow pass
class WASM_GOTO < INSTRUCTION
  children :label
end

# Marker for CBRANCH - will be transformed in control flow pass
class WASM_CBRANCH < INSTRUCTION
  children :true_label, :false_label
end
