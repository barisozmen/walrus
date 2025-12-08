# frozen_string_literal: true

require_relative 'jvm_type_mapper'

module Walrus
  # Represents a single JVM bytecode instruction
  class JVMInstruction
    attr_reader :opcode, :operands

    def initialize(opcode, *operands)
      @opcode = opcode
      @operands = operands
    end

    def to_s
      if operands.empty?
        opcode.to_s
      else
        "#{opcode} #{operands.join(', ')}"
      end
    end

    def ==(other)
      other.is_a?(JVMInstruction) && opcode == other.opcode && operands == other.operands
    end
  end

  # Helper class for building JVM bytecode instructions
  # Tracks stack depth and provides convenient instruction emission
  class JVMBytecodeBuilder
    attr_reader :instructions, :max_stack, :label_counter

    def initialize
      @instructions = []
      @stack_depth = 0
      @max_stack = 0
      @label_counter = 0
    end

    # Generate unique label
    def gen_label(prefix = 'L')
      @label_counter += 1
      "#{prefix}#{@label_counter}"
    end

    # Emit bytecode instruction
    def emit(opcode, *operands)
      @instructions << JVMInstruction.new(opcode, *operands)
      update_stack_depth(opcode, operands)
      self
    end

    # Push constants
    def push_int(value)
      case value
      when 0 then emit(:iconst_0)
      when 1 then emit(:iconst_1)
      when 2 then emit(:iconst_2)
      when 3 then emit(:iconst_3)
      when 4 then emit(:iconst_4)
      when 5 then emit(:iconst_5)
      when -1 then emit(:iconst_m1)
      when -128..127 then emit(:bipush, value)
      when -32768..32767 then emit(:sipush, value)
      else emit(:ldc, value)
      end
    end

    def push_double(value)
      if value == 0.0
        emit(:dconst_0)
      elsif value == 1.0
        emit(:dconst_1)
      else
        emit(:ldc2_w, value)
      end
    end

    def push_string(value)
      emit(:ldc, value)
    end

    # Arithmetic (stack: ..., value1, value2 -> ..., result)
    def iadd() emit(:iadd) end
    def dadd() emit(:dadd) end
    def isub() emit(:isub) end
    def dsub() emit(:dsub) end
    def imul() emit(:imul) end
    def dmul() emit(:dmul) end
    def idiv() emit(:idiv) end
    def ddiv() emit(:ddiv) end
    def ineg() emit(:ineg) end
    def dneg() emit(:dneg) end

    # Comparisons for integers
    def if_icmplt(label) emit(:if_icmplt, label) end
    def if_icmpgt(label) emit(:if_icmpgt, label) end
    def if_icmple(label) emit(:if_icmple, label) end
    def if_icmpge(label) emit(:if_icmpge, label) end
    def if_icmpeq(label) emit(:if_icmpeq, label) end
    def if_icmpne(label) emit(:if_icmpne, label) end

    # Comparisons for doubles (stack: ..., value1, value2 -> ..., result)
    def dcmpg() emit(:dcmpg) end
    def dcmpl() emit(:dcmpl) end

    # Boolean comparisons
    def ifeq(label) emit(:ifeq, label) end
    def ifne(label) emit(:ifne, label) end
    def iflt(label) emit(:iflt, label) end
    def ifgt(label) emit(:ifgt, label) end
    def ifle(label) emit(:ifle, label) end
    def ifge(label) emit(:ifge, label) end

    # Local variables
    def iload(index)
      case index
      when 0 then emit(:iload_0)
      when 1 then emit(:iload_1)
      when 2 then emit(:iload_2)
      when 3 then emit(:iload_3)
      else emit(:iload, index)
      end
    end

    def dload(index)
      case index
      when 0 then emit(:dload_0)
      when 1 then emit(:dload_1)
      when 2 then emit(:dload_2)
      when 3 then emit(:dload_3)
      else emit(:dload, index)
      end
    end

    def aload(index)
      case index
      when 0 then emit(:aload_0)
      when 1 then emit(:aload_1)
      when 2 then emit(:aload_2)
      when 3 then emit(:aload_3)
      else emit(:aload, index)
      end
    end

    def istore(index)
      case index
      when 0 then emit(:istore_0)
      when 1 then emit(:istore_1)
      when 2 then emit(:istore_2)
      when 3 then emit(:istore_3)
      else emit(:istore, index)
      end
    end

    def dstore(index)
      case index
      when 0 then emit(:dstore_0)
      when 1 then emit(:dstore_1)
      when 2 then emit(:dstore_2)
      when 3 then emit(:dstore_3)
      else emit(:dstore, index)
      end
    end

    def astore(index)
      case index
      when 0 then emit(:astore_0)
      when 1 then emit(:astore_1)
      when 2 then emit(:astore_2)
      when 3 then emit(:astore_3)
      else emit(:astore, index)
      end
    end

    # Static fields (globals)
    def getstatic(class_name, field_name, descriptor)
      emit(:getstatic, "#{class_name}.#{field_name}", descriptor)
    end

    def putstatic(class_name, field_name, descriptor)
      emit(:putstatic, "#{class_name}.#{field_name}", descriptor)
    end

    # Method invocation
    def invokestatic(class_name, method_name, descriptor)
      emit(:invokestatic, "#{class_name}.#{method_name}", descriptor)
    end

    def invokevirtual(class_name, method_name, descriptor)
      emit(:invokevirtual, "#{class_name}.#{method_name}", descriptor)
    end

    # Control flow
    def goto(label)
      emit(:goto, label)
    end

    # Return
    def ireturn() emit(:ireturn) end
    def dreturn() emit(:dreturn) end
    def areturn() emit(:areturn) end
    def voidreturn() emit(:return) end

    # Stack manipulation
    def dup() emit(:dup) end
    def dup2() emit(:dup2) end
    def pop() emit(:pop) end
    def pop2() emit(:pop2) end
    def swap() emit(:swap) end

    # Labels (for control flow)
    def label(name)
      emit(:label, name)
    end

    # Type conversions
    def i2d() emit(:i2d) end  # int to double
    def d2i() emit(:d2i) end  # double to int
    def i2c() emit(:i2c) end  # int to char

    private

    # Stack effect table for each opcode
    STACK_EFFECTS = {
      # Constants
      iconst_0: +1, iconst_1: +1, iconst_2: +1, iconst_3: +1, iconst_4: +1, iconst_5: +1, iconst_m1: +1,
      dconst_0: +2, dconst_1: +2,
      bipush: +1, sipush: +1, ldc: +1, ldc2_w: +2,

      # Arithmetic
      iadd: -1, dadd: -2, isub: -1, dsub: -2, imul: -1, dmul: -2, idiv: -1, ddiv: -2,
      ineg: 0, dneg: 0,

      # Local variables
      iload: +1, iload_0: +1, iload_1: +1, iload_2: +1, iload_3: +1,
      dload: +2, dload_0: +2, dload_1: +2, dload_2: +2, dload_3: +2,
      aload: +1, aload_0: +1, aload_1: +1, aload_2: +1, aload_3: +1,
      istore: -1, istore_0: -1, istore_1: -1, istore_2: -1, istore_3: -1,
      dstore: -2, dstore_0: -2, dstore_1: -2, dstore_2: -2, dstore_3: -2,
      astore: -1, astore_0: -1, astore_1: -1, astore_2: -1, astore_3: -1,

      # Fields (conservatively assume +1 for gets, -1 for puts)
      getstatic: +1, putstatic: -1,

      # Method calls (special handling needed)
      invokestatic: 0, invokevirtual: 0,

      # Comparisons
      if_icmplt: -2, if_icmpgt: -2, if_icmple: -2, if_icmpge: -2,
      if_icmpeq: -2, if_icmpne: -2,
      dcmpg: -3, dcmpl: -3,  # Consumes 2 doubles (4 slots), pushes 1 int
      ifeq: -1, ifne: -1, iflt: -1, ifgt: -1, ifle: -1, ifge: -1,

      # Control flow
      goto: 0,

      # Return
      ireturn: -1, dreturn: -2, areturn: -1, return: 0,

      # Stack manipulation
      dup: +1, dup2: +2, pop: -1, pop2: -2, swap: 0,

      # Type conversions
      i2d: +1, d2i: -1, i2c: 0,

      # Labels
      label: 0
    }.freeze

    def update_stack_depth(opcode, operands)
      effect = STACK_EFFECTS[opcode]

      # Special handling for method calls
      if opcode == :invokestatic || opcode == :invokevirtual
        # Parse descriptor to calculate effect
        descriptor = operands[1]
        effect = calculate_method_stack_effect(descriptor, opcode == :invokevirtual)
      elsif opcode == :getstatic || opcode == :putstatic
        # Parse field descriptor
        descriptor = operands[1]
        effect = opcode == :getstatic ? field_stack_effect(descriptor, true) : field_stack_effect(descriptor, false)
      end

      effect ||= 0  # Default to 0 if unknown
      @stack_depth += effect
      @stack_depth = 0 if @stack_depth < 0  # Floor at 0
      @max_stack = [@max_stack, @stack_depth].max
    end

    # Calculate stack effect for method calls
    def calculate_method_stack_effect(descriptor, is_virtual)
      # Parse descriptor like "(II)I" or "(D)V"
      return 0 unless descriptor =~ /\(([^)]*)\)(.+)/

      params = $1
      return_type = $2

      # Count parameter slots
      param_slots = 0
      i = 0
      while i < params.length
        case params[i]
        when 'D', 'J' then param_slots += 2  # double, long take 2 slots
        when 'L'
          # Object reference - find semicolon
          i = params.index(';', i)
          param_slots += 1
        else
          param_slots += 1
        end
        i += 1
      end

      # Add 1 for 'this' reference if virtual
      param_slots += 1 if is_virtual

      # Calculate return slots
      return_slots = case return_type
                     when 'V' then 0
                     when 'D', 'J' then 2
                     else 1
                     end

      return_slots - param_slots
    end

    # Calculate stack effect for field access
    def field_stack_effect(descriptor, is_get)
      slots = case descriptor
              when 'D', 'J' then 2
              else 1
              end

      is_get ? slots : -slots
    end
  end
end
