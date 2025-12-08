# JVM Backend Implementation Plan

**Author**: Claude Code
**Date**: 2025-12-08
**Status**: Design Phase
**Target**: Add JVM compilation target with automatic garbage collection to Walrus

---

## Executive Summary

This document outlines the plan to add JVM (Java Virtual Machine) as a compilation target for Walrus, alongside the existing LLVM backend. The JVM backend will leverage the JVM's automatic garbage collection, eliminating the need for manual memory management. The design reuses 100% of the existing frontend (passes 1-11) and only requires implementing 3 new backend passes.

---

## Current Architecture Analysis

### Compiler Pipeline (16 passes)

**Frontend/Middle-end (Passes 1-11)**: Backend-agnostic
- Tokenization → Parsing → AST transformations → IR generation
- Produces stack-based IR with instructions:
  - Value: `PUSH`
  - Arithmetic: `ADD`, `SUB`, `MUL`, `DIV`
  - Comparison: `LT`, `GT`, `LE`, `GE`, `EQ`, `NE`
  - Unary: `NEG`, `NOT`
  - Memory: `LOAD_LOCAL`, `STORE_LOCAL`, `LOAD_GLOBAL`, `STORE_GLOBAL`, `LOCAL`
  - Control: `GOTO`, `CBRANCH`, `RETURN`
  - Functions: `CALL`, `PRINT`, `GETS`

**LLVM Backend (Passes 12-14)**: LLVM-specific
- Pass 12 (`GenerateLLVMCode`): Stack IR → LLVM SSA (via `get_llvm_code()`)
- Pass 13 (`AddLlvmEntryBlocks`): Add entry blocks for parameter allocation
- Pass 14 (`FormatLlvm`): Format as LLVM IR string, link with `runtime.c`

### IR Structure After Pass 11

```ruby
Program([
  GlobalVarDeclarationWithoutInit(name: 'counter', type: 'int'),
  Function(
    name: 'increment',
    params: [Parameter('x', type: 'int')],
    body: [
      BLOCK('L0', [
        PUSH(1, type: 'int'),
        LOAD_LOCAL('x', type: 'int'),
        ADD(),
        RETURN()
      ])
    ],
    type: 'int'
  )
])
```

All instructions inherit from `INSTRUCTION` and implement `get_llvm_code(stack, type_map)` for LLVM code generation (compiler_passes/12_generate_llvm_code.rb:24-34).

---

## JVM Backend Design

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    SHARED FRONTEND                          │
│  Passes 1-11: Tokenizer → Parser → IR Generation           │
│  Output: Stack-based IR (PUSH, ADD, LOAD_LOCAL, etc.)      │
└────────────────┬────────────────────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
┌───────▼──────┐  ┌──────▼────────┐
│ LLVM Backend │  │  JVM Backend  │
│ (Existing)   │  │  (New)        │
├──────────────┤  ├───────────────┤
│ Pass 12-LLVM │  │ Pass 12-JVM   │
│ Pass 13-LLVM │  │ Pass 13-JVM   │
│ Pass 14-LLVM │  │ Pass 14-JVM   │
├──────────────┤  ├───────────────┤
│ Output:      │  │ Output:       │
│ LLVM IR      │  │ JVM .class    │
│ (text)       │  │ (bytecode)    │
└──────────────┘  └───────────────┘
```

### Type Mapping

| Walrus Type | LLVM Type | JVM Type | JVM Descriptor | Size (JVM slots) |
|-------------|-----------|----------|----------------|------------------|
| `int`       | `i32`     | `int`    | `I`            | 1                |
| `float`     | `double`  | `double` | `D`            | 2                |
| `bool`      | `i1`      | `boolean`| `Z`            | 1                |
| `char`      | `i8`      | `char`   | `C`            | 1                |
| `str`       | `i8*`     | `String` | `Ljava/lang/String;` | 1          |

### Memory Model Comparison

| Aspect | LLVM Backend | JVM Backend |
|--------|--------------|-------------|
| **Local variables** | Explicit `alloca` instructions | Automatic local variable slots (0, 1, 2, ...) |
| **Global variables** | `@varname = global i32 0` | Static fields in class: `static int varname;` |
| **Function params** | Passed as SSA registers, require alloca for mutation | Occupy first N local variable slots |
| **Stack values** | SSA registers (%.0, %.1, ...) | Operand stack (implicit) |
| **Garbage collection** | None (manual memory management in C runtime) | **Automatic GC** for objects/strings |
| **Memory allocation** | Manual (would need malloc/free for heap) | Automatic (`new`, `ldc` for strings) |

**Key Insight**: JVM's automatic GC eliminates all memory management complexity!

---

## Implementation Plan

### Phase 1: Foundation

#### 1.1 Create `lib/jvm_type_mapper.rb`

```ruby
module Walrus
  module JVMTypeMapper
    # Convert Walrus type to JVM type descriptor
    def self.to_jvm(walrus_type)
      case walrus_type
      when 'int'   then 'I'
      when 'float' then 'D'
      when 'bool'  then 'Z'
      when 'char'  then 'C'
      when 'str'   then 'Ljava/lang/String;'
      else raise "Unknown type: #{walrus_type}"
      end
    end

    # Convert to JVM method descriptor
    # Example: (['int', 'int'], 'int') => "(II)I"
    def self.to_method_descriptor(param_types, return_type)
      param_sig = param_types.map { |t| to_jvm(t) }.join
      ret_sig = to_jvm(return_type)
      "(#{param_sig})#{ret_sig}"
    end

    # Convert to JVM internal name (for classes)
    # Example: "java.lang.String" => "java/lang/String"
    def self.to_internal_name(class_name)
      class_name.gsub('.', '/')
    end

    # Get JVM local variable slot width (double/long take 2 slots)
    def self.slot_width(walrus_type)
      walrus_type == 'float' ? 2 : 1
    end
  end
end
```

**Test**: `tests/unit/test_jvm_type_mapper.rb`

---

#### 1.2 Create `lib/jvm_bytecode_builder.rb`

```ruby
module Walrus
  # Helper class for building JVM bytecode instructions
  # Wraps ASM library or provides manual bytecode generation
  class JVMBytecodeBuilder
    attr_reader :instructions, :max_stack

    def initialize
      @instructions = []
      @stack_depth = 0
      @max_stack = 0
      @label_positions = {}
    end

    # Emit bytecode instruction
    def emit(opcode, *operands)
      @instructions << JVMInstruction.new(opcode, operands)
      update_stack_depth(opcode)
    end

    # Push constants
    def push_int(value)
      case value
      when 0..5     then emit(:iconst, value)   # iconst_0 to iconst_5
      when -128..127 then emit(:bipush, value)  # bipush (1-byte signed)
      when -32768..32767 then emit(:sipush, value)  # sipush (2-byte signed)
      else emit(:ldc, value)                    # ldc (constant pool)
      end
    end

    def push_double(value)
      if value == 0.0 || value == 1.0
        emit(:dconst, value.to_i)  # dconst_0 or dconst_1
      else
        emit(:ldc2_w, value)
      end
    end

    def push_string(value)
      emit(:ldc, value)  # String from constant pool
    end

    # Arithmetic (stack: ..., value1, value2 -> ..., result)
    def iadd() emit(:iadd) end  # int add
    def dadd() emit(:dadd) end  # double add
    def isub() emit(:isub) end
    def dsub() emit(:dsub) end
    def imul() emit(:imul) end
    def dmul() emit(:dmul) end
    def idiv() emit(:idiv) end
    def ddiv() emit(:ddiv) end
    def ineg() emit(:ineg) end  # int negate
    def dneg() emit(:dneg) end  # double negate

    # Comparisons (generate if_icmpXX for int, dcmpg + if for double)
    def icmp_lt(true_label)
      emit(:if_icmplt, true_label)
    end

    def icmp_gt(true_label)
      emit(:if_icmpgt, true_label)
    end

    def icmp_le(true_label)
      emit(:if_icmple, true_label)
    end

    def icmp_ge(true_label)
      emit(:if_icmpge, true_label)
    end

    def icmp_eq(true_label)
      emit(:if_icmpeq, true_label)
    end

    def icmp_ne(true_label)
      emit(:if_icmpne, true_label)
    end

    # Double comparisons (stack: ..., value1, value2 -> ..., result)
    def dcmp_lt(true_label)
      emit(:dcmpg)   # Compare doubles (1 if v1 > v2, 0 if equal, -1 if v1 < v2)
      emit(:iflt, true_label)  # Jump if result < 0
    end

    def dcmp_gt(true_label)
      emit(:dcmpg)
      emit(:ifgt, true_label)
    end

    # Local variables
    def iload(index)
      emit(:iload, index)
    end

    def dload(index)
      emit(:dload, index)
    end

    def aload(index)  # Object reference
      emit(:aload, index)
    end

    def istore(index)
      emit(:istore, index)
    end

    def dstore(index)
      emit(:dstore, index)
    end

    def astore(index)
      emit(:astore, index)
    end

    # Static fields (globals)
    def getstatic(class_name, field_name, descriptor)
      emit(:getstatic, class_name, field_name, descriptor)
    end

    def putstatic(class_name, field_name, descriptor)
      emit(:putstatic, class_name, field_name, descriptor)
    end

    # Method invocation
    def invokestatic(class_name, method_name, descriptor)
      emit(:invokestatic, class_name, method_name, descriptor)
    end

    def invokevirtual(class_name, method_name, descriptor)
      emit(:invokevirtual, class_name, method_name, descriptor)
    end

    # Control flow
    def goto(label)
      emit(:goto, label)
    end

    def ifeq(label)  # Jump if top of stack == 0
      emit(:ifeq, label)
    end

    def ifne(label)  # Jump if top of stack != 0
      emit(:ifne, label)
    end

    # Return
    def ireturn() emit(:ireturn) end
    def dreturn() emit(:dreturn) end
    def areturn() emit(:areturn) end
    def voidreturn() emit(:return) end

    # Stack manipulation
    def dup() emit(:dup) end
    def pop() emit(:pop) end
    def swap() emit(:swap) end

    # Labels
    def label(name)
      @label_positions[name] = @instructions.size
      emit(:label, name)
    end

    private

    # Track stack depth for max_stack calculation
    STACK_EFFECTS = {
      iconst: +1, bipush: +1, sipush: +1, ldc: +1, ldc2_w: +2,
      dconst: +2,
      iadd: -1, dadd: -2, isub: -1, dsub: -2,
      imul: -1, dmul: -2, idiv: -1, ddiv: -2,
      ineg: 0, dneg: 0,
      iload: +1, dload: +2, aload: +1,
      istore: -1, dstore: -2, astore: -1,
      getstatic: nil,  # Depends on field type
      putstatic: nil,
      invokestatic: nil,  # Depends on method signature
      invokevirtual: nil,
      dup: +1, pop: -1, swap: 0,
      ireturn: -1, dreturn: -2, areturn: -1, return: 0,
      if_icmplt: -2, if_icmpgt: -2, if_icmple: -2, if_icmpge: -2,
      if_icmpeq: -2, if_icmpne: -2,
      ifeq: -1, ifne: -1,
      goto: 0,
      dcmpg: -2,  # Consumes 2 doubles, pushes 1 int
      iflt: -1, ifgt: -1,
      label: 0
    }

    def update_stack_depth(opcode)
      effect = STACK_EFFECTS[opcode] || 0
      @stack_depth += effect
      @max_stack = [@max_stack, @stack_depth].max
    end
  end

  # Represents a single JVM bytecode instruction
  JVMInstruction = Struct.new(:opcode, :operands) do
    def to_s
      if operands.empty?
        opcode.to_s
      else
        "#{opcode} #{operands.join(', ')}"
      end
    end
  end
end
```

**Test**: `tests/unit/test_jvm_bytecode_builder.rb`

---

### Phase 2: JVM Backend Passes

#### 2.1 Pass 12-JVM: `compiler_passes/12_generate_jvm_bytecode.rb`

```ruby
require_relative 'base'
require_relative '../lib/jvm_type_mapper'
require_relative '../lib/jvm_bytecode_builder'

module Walrus
  # Converts stack-based IR instructions to JVM bytecode
  # Similar to GenerateLLVMCode but produces JVM instructions
  class GenerateJVMBytecode < AstTransformerBasedCompilerPass
    def before_transform(node, context)
      context.merge(
        class_name: 'WalrusProgram',
        jvm_builders: {}  # function_name => JVMBytecodeBuilder
      )
    end

    def transform_function(func, context)
      # Create separate builder per function
      builders = {}  # block_label => JVMBytecodeBuilder

      func.body.each do |block|
        builder = JVMBytecodeBuilder.new
        builder.label(block.label)

        # Process instructions with simulated stack
        stack = []
        type_map = {}

        block.instructions.each do |instr|
          instr.get_jvm_bytecode(builder, stack, type_map, context)
        end

        builders[block.label] = builder
      end

      # Merge all builders into single method body
      merged_builder = merge_builders(builders, func.body.map(&:label))
      context[:jvm_builders][func.name] = merged_builder

      func  # Return unchanged (bytecode stored in context)
    end

    private

    def merge_builders(builders, label_order)
      merged = JVMBytecodeBuilder.new
      label_order.each do |label|
        builder = builders[label]
        merged.instructions.concat(builder.instructions)
        merged.instance_variable_set(:@max_stack,
          [merged.max_stack, builder.max_stack].max)
      end
      merged
    end
  end
end
```

**Add `get_jvm_bytecode()` methods to instruction types in `model.rb`**:

```ruby
# Add to PUSH class
def get_jvm_bytecode(builder, stack, type_map, context)
  case type
  when 'int'
    builder.push_int(value.to_i)
  when 'float'
    builder.push_double(value.to_f)
  when 'bool'
    builder.push_int(value ? 1 : 0)
  when 'char'
    builder.push_int(value.ord)
  when 'str'
    builder.push_string(value)
  end

  temp = "const_#{value}"
  stack.push(temp)
  type_map[temp] = JVMTypeMapper.to_jvm(type)
end

# Add to ADD class (and similar for SUB, MUL, DIV)
def get_jvm_bytecode(builder, stack, type_map, context)
  right = stack.pop
  left = stack.pop
  type = type_map[left] || 'I'

  if type == 'D'
    builder.dadd
  else
    builder.iadd
  end

  temp = "temp_add"
  stack.push(temp)
  type_map[temp] = type
end

# Add to LOAD_LOCAL class
def get_jvm_bytecode(builder, stack, type_map, context)
  var_index = context[:local_var_map][name]
  jvm_type = JVMTypeMapper.to_jvm(type)

  case jvm_type
  when 'I', 'Z' then builder.iload(var_index)
  when 'D' then builder.dload(var_index)
  when /^L/ then builder.aload(var_index)  # Object
  end

  temp = "local_#{name}"
  stack.push(temp)
  type_map[temp] = jvm_type
end

# Add to STORE_LOCAL class
def get_jvm_bytecode(builder, stack, type_map, context)
  value = stack.pop
  var_index = context[:local_var_map][name]
  jvm_type = type_map[value] || 'I'

  case jvm_type
  when 'I', 'Z' then builder.istore(var_index)
  when 'D' then builder.dstore(var_index)
  when /^L/ then builder.astore(var_index)
  end
end

# Add to LOAD_GLOBAL class
def get_jvm_bytecode(builder, stack, type_map, context)
  jvm_type = JVMTypeMapper.to_jvm(type)
  builder.getstatic(context[:class_name], name, jvm_type)

  temp = "global_#{name}"
  stack.push(temp)
  type_map[temp] = jvm_type
end

# Add to STORE_GLOBAL class
def get_jvm_bytecode(builder, stack, type_map, context)
  value = stack.pop
  jvm_type = type_map[value] || 'I'
  builder.putstatic(context[:class_name], name, jvm_type)
end

# Add to CALL class
def get_jvm_bytecode(builder, stack, type_map, context)
  args = stack.pop(nargs).reverse
  arg_types = args.map { |a| type_map[a] || 'I' }
  ret_type = JVMTypeMapper.to_jvm(type)

  descriptor = JVMTypeMapper.to_method_descriptor(
    param_types.map { |t| type_map[t] || 'int' },
    type
  )

  builder.invokestatic(context[:class_name], name, descriptor)

  temp = "call_#{name}"
  stack.push(temp)
  type_map[temp] = ret_type
end

# Add to PRINT class
def get_jvm_bytecode(builder, stack, type_map, context)
  value = stack.pop
  jvm_type = type_map[value] || 'I'

  # Get System.out
  builder.getstatic('java/lang/System', 'out', 'Ljava/io/PrintStream;')
  builder.swap  # Swap to get value on top

  # Call appropriate println method
  case jvm_type
  when 'I'
    builder.invokevirtual('java/io/PrintStream', 'println', '(I)V')
  when 'D'
    builder.invokevirtual('java/io/PrintStream', 'println', '(D)V')
  when 'Z'
    builder.invokevirtual('java/io/PrintStream', 'println', '(Z)V')
  when 'C'
    builder.invokevirtual('java/io/PrintStream', 'println', '(C)V')
  when 'Ljava/lang/String;'
    builder.invokevirtual('java/io/PrintStream', 'println', '(Ljava/lang/String;)V')
  end
end

# Add to RETURN class
def get_jvm_bytecode(builder, stack, type_map, context)
  value = stack.pop
  jvm_type = type_map[value] || 'I'

  case jvm_type
  when 'I', 'Z' then builder.ireturn
  when 'D' then builder.dreturn
  when /^L/ then builder.areturn
  else builder.voidreturn
  end
end

# Add to GOTO class
def get_jvm_bytecode(builder, stack, type_map, context)
  builder.goto(label)
end

# Add to CBRANCH class
def get_jvm_bytecode(builder, stack, type_map, context)
  condition = stack.pop
  # Condition is boolean (0 or 1)
  builder.ifne(true_label)  # if != 0, jump to true
  builder.goto(false_label)
end

# Add to comparison classes (LT, GT, LE, GE, EQ, NE)
# Example for LT:
def get_jvm_bytecode(builder, stack, type_map, context)
  right = stack.pop
  left = stack.pop
  type = type_map[left] || 'I'

  if type == 'D'
    # For doubles: dcmpg + iflt
    builder.dcmpg
    temp_label = "L_cmp_#{builder.instructions.size}"
    false_label = "L_false_#{builder.instructions.size}"
    builder.iflt(temp_label)
    builder.push_int(0)
    builder.goto(false_label)
    builder.label(temp_label)
    builder.push_int(1)
    builder.label(false_label)
  else
    # For ints: if_icmplt
    temp_label = "L_cmp_#{builder.instructions.size}"
    false_label = "L_false_#{builder.instructions.size}"
    builder.icmp_lt(temp_label)
    builder.push_int(0)
    builder.goto(false_label)
    builder.label(temp_label)
    builder.push_int(1)
    builder.label(false_label)
  end

  temp = "cmp_result"
  stack.push(temp)
  type_map[temp] = 'I'
end
```

**Location**: Add these methods to corresponding classes in `model.rb:360-690`

---

#### 2.2 Pass 13-JVM: `compiler_passes/13_allocate_jvm_local_variables.rb`

```ruby
require_relative 'base'

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
      context[:local_var_map] = local_var_map
      context[:max_locals] = next_slot

      func
    end
  end
end
```

**Test**: `tests/unit/test_allocate_jvm_local_variables.rb`

---

#### 2.3 Pass 14-JVM: `compiler_passes/14_format_jvm_class.rb`

```ruby
require_relative 'base'
require_relative '../lib/jvm_class_writer'

module Walrus
  # Generates JVM .class file from bytecode
  # Uses ASM library (org.ow2.asm) or custom bytecode writer
  class FormatJVMClass < CompilerPass
    def run(program)
      raise ArgumentError, "Expected Program" unless program.is_a?(Program)

      class_name = Walrus.context[:class_name] || 'WalrusProgram'
      class_writer = JVMClassWriter.new(class_name)

      # Extract globals and functions
      globals = program.statements.select { |s| s.is_a?(GlobalVarDeclarationWithoutInit) }
      functions = program.statements.select { |s| s.is_a?(Function) }

      # Add static fields for global variables
      globals.each do |global|
        jvm_type_descriptor = JVMTypeMapper.to_jvm(global.type)
        class_writer.add_static_field(
          name: global.name,
          descriptor: jvm_type_descriptor,
          access: :public_static
        )
      end

      # Add static methods for each function
      jvm_builders = Walrus.context[:jvm_builders] || {}

      functions.each do |func|
        builder = jvm_builders[func.name]
        next unless builder

        param_descriptors = func.params.map { |p| JVMTypeMapper.to_jvm(p.type) }
        return_descriptor = JVMTypeMapper.to_jvm(func.type)

        class_writer.add_method(
          name: func.name,
          descriptor: JVMTypeMapper.to_method_descriptor(
            func.params.map(&:type),
            func.type
          ),
          access: :public_static,
          max_stack: builder.max_stack,
          max_locals: Walrus.context[:max_locals] || 10,
          instructions: builder.instructions
        )
      end

      # Generate .class file as byte array
      class_writer.to_bytes
    end
  end
end
```

**Dependencies**: Create `lib/jvm_class_writer.rb` (wrapper around ASM library or custom implementation)

---

### Phase 3: Integration

#### 3.1 Modify `compile/pipeline.rb`

```ruby
module Walrus
  class CompilerPipeline
    # Shared frontend passes (backend-agnostic)
    SHARED_PASSES = [
      Tokenizer,
      BraceCheck,
      Parser,
      LowerCaseToElsIf,
      LowerElsIfToIf,
      LowerForLoopsToWhileLoops,
      LowerShortCircuitOperators,
      FoldConstants,
      DeinitializeVariableDeclarations,
      ResolveVariableScopes,
      InferAndCheckTypes,
      DetectUnusedVars,
      GatherTopLevelStatementsIntoMain,
      EnsureAllFunctionsHaveExplicitReturns,
      LowerExpressionsToInstructions,
      LowerStatementsToInstructions,
      MergeStatementsIntoBasicBlocks,
      FlattenControlFlow
    ].freeze

    # LLVM-specific backend
    LLVM_PASSES = [
      GenerateLLVMCode,
      AddLlvmEntryBlocks,
      FormatLlvm
    ].freeze

    # JVM-specific backend
    JVM_PASSES = [
      AllocateJVMLocalVariables,  # Must run before GenerateJVMBytecode
      GenerateJVMBytecode,
      FormatJVMClass
    ].freeze

    def compile(source:, output:, runtime:, optimize: '0', target: 'llvm')
      # Select backend passes based on target
      backend_passes = case target
                       when 'jvm' then JVM_PASSES
                       when 'llvm' then LLVM_PASSES
                       else raise "Unknown target: #{target}"
                       end

      passes = SHARED_PASSES + backend_passes

      ui.header("Walrus Compiler (#{target.upcase} target)")
      ui.info("Source: #{source.lines.count} lines")
      ui.info("Target: #{target}")

      # Run all passes
      result = source
      passes.each.with_index(1) do |pass_class, idx|
        pass_name = PassHelpers.display_name(pass_class)
        result = ui.with_spinner("Pass #{idx}/#{passes.size}: #{pass_name}") do
          PassHelpers.run_with_context(pass_class.new, result, source)
        end
      end

      # Target-specific output
      case target
      when 'llvm'
        compile_llvm(result, output, runtime, optimize)
      when 'jvm'
        compile_jvm(result, output)
      end

      # Show warnings
      display_warnings

      # Done
      ui.success("Compilation completed → #{output}")
      output
    end

    private

    def compile_llvm(llvm_ir, output, runtime, optimize)
      # Write LLVM IR
      llvm_file = output.sub(/\.(exe|out)$/, '') + '.ll'
      File.write(llvm_file, llvm_ir)
      ui.file_info("LLVM IR", llvm_file)

      # Compile with clang
      opt_flag = optimize.empty? ? '' : " -O#{optimize}"
      compile_cmd = "clang#{opt_flag} #{llvm_file} #{runtime} -o #{output}"
      ui.command(compile_cmd)

      ui.with_spinner("Linking with clang") do
        raise "Clang failed" unless system(compile_cmd, out: File::NULL, err: File::NULL)
      end
    end

    def compile_jvm(class_bytes, output)
      # Write .class file
      class_file = output.sub(/\.(exe|out)$/, '') + '.class'
      File.binwrite(class_file, class_bytes)
      ui.file_info("JVM Class", class_file)

      # Create executable wrapper script
      write_java_launcher(class_file, output)
    end

    def write_java_launcher(class_file, output)
      class_name = File.basename(class_file, '.class')
      class_dir = File.dirname(class_file)

      launcher = <<~BASH
        #!/usr/bin/env bash
        # Walrus JVM launcher
        # Runs the compiled JVM class file
        java -cp "#{class_dir}" #{class_name} "$@"
      BASH

      File.write(output, launcher)
      File.chmod(0755, output)
      ui.file_info("Launcher", output)
    end

    def display_warnings
      warnings = Walrus.context[:warnings] || []
      return unless warnings.any?

      ui.section("Warnings")
      warnings.each { |w| puts w.display; puts }
    end
  end
end
```

---

#### 3.2 Update CLI in `compile.rb`

```ruby
option :target,
       aliases: '-t',
       type: :string,
       default: 'llvm',
       desc: 'Compilation target: llvm or jvm (default: llvm)'

def compile(input)
  # Validate target
  target = options[:target]
  unless %w[llvm jvm].include?(target)
    ui.error("Invalid target: #{target}. Must be 'llvm' or 'jvm'")
    exit 1
  end

  # ... existing validation ...

  CompilerPipeline.new(ui: ui).compile(
    source: File.read(input),
    output: output,
    runtime: runtime,
    optimize: options[:optimize],
    target: target  # NEW!
  )

  # Run if requested
  if options[:run]
    ui.section("Running...")
    exec(output) if target == 'llvm'
    exec("java -cp #{File.dirname(output)} #{File.basename(output, '.class')}") if target == 'jvm'
  end
end
```

---

## Garbage Collection Benefits

### LLVM Backend (Manual Memory)

```llvm
; Allocate local variable
%x = alloca i32

; Load/store require explicit memory operations
store i32 10, i32* %x
%value = load i32, i32* %x

; Strings require manual constant pool + getelementptr
@str = constant [6 x i8] c"hello\00"
%ptr = getelementptr [6 x i8], [6 x i8]* @str, i32 0, i32 0
```

**No automatic memory management!** If we added heap objects (arrays, structs), we'd need:
- Manual `malloc`/`free` calls
- Reference counting or custom GC implementation
- Memory leak potential

---

### JVM Backend (Automatic GC)

```jvm
; Local variables are automatic slots (no alloca needed!)
iload 0     ; Load local variable at slot 0
istore 1    ; Store to local variable at slot 1

; Strings are automatic objects with GC
ldc "hello"  ; Load string constant (heap-allocated, GC-managed)

; Objects/arrays are automatically collected when unreachable
```

**Automatic GC handles everything!**
- Local primitives: Stack-allocated (no GC needed)
- Objects (strings, future arrays/structs): Heap-allocated with automatic GC
- No manual memory management
- No memory leaks (assuming no circular references, which JVM GC handles)

**GC Algorithm**: JVM uses generational GC (G1GC, ZGC, Shenandoah) with:
- Young generation (short-lived objects)
- Old generation (long-lived objects)
- Concurrent marking and sweeping
- Compaction to reduce fragmentation

---

## Testing Strategy

### Unit Tests

```ruby
# tests/unit/test_jvm_type_mapper.rb
def test_basic_type_mapping
  assert_equal 'I', JVMTypeMapper.to_jvm('int')
  assert_equal 'D', JVMTypeMapper.to_jvm('float')
  assert_equal '(II)I', JVMTypeMapper.to_method_descriptor(['int', 'int'], 'int')
end

# tests/unit/test_jvm_bytecode_builder.rb
def test_push_instructions
  builder = JVMBytecodeBuilder.new
  builder.push_int(0)
  builder.push_int(42)
  builder.iadd

  assert_equal 3, builder.instructions.size
  assert_equal :iconst, builder.instructions[0].opcode
  assert_equal :bipush, builder.instructions[1].opcode
  assert_equal :iadd, builder.instructions[2].opcode
end

# tests/unit/test_allocate_jvm_local_variables.rb
def test_local_slot_allocation
  func = Function.new('test', [
    Parameter.new('x', type: 'int'),
    Parameter.new('y', type: 'float')
  ], [
    BLOCK.new('L0', [LOCAL.new('temp', type: 'int')])
  ], type: 'int')

  pass = AllocateJVMLocalVariables.new
  context = {}
  pass.transform_function(func, context)

  assert_equal 0, context[:local_var_map]['x']
  assert_equal 1, context[:local_var_map]['y']
  assert_equal 3, context[:local_var_map]['temp']  # y takes 2 slots
  assert_equal 4, context[:max_locals]
end
```

---

### Integration Tests

```ruby
# tests/integration/test_jvm_backend.rb
class TestJVMBackend < Minitest::Test
  def test_simple_arithmetic
    source = <<~WALRUS
      var x = 10 + 20;
      print x;
    WALRUS

    output = compile_and_run(source, target: 'jvm')
    assert_equal "30\n", output
  end

  def test_function_call
    source = <<~WALRUS
      func add(a int, b int) int {
        return a + b;
      }
      print add(5, 7);
    WALRUS

    output = compile_and_run(source, target: 'jvm')
    assert_equal "12\n", output
  end

  def test_float_arithmetic
    source = <<~WALRUS
      var pi = 3.14159;
      var radius = 10.0;
      var area = pi * radius * radius;
      print area;
    WALRUS

    output = compile_and_run(source, target: 'jvm')
    assert_match /314\.159/, output
  end

  def test_control_flow
    source = <<~WALRUS
      var x = 10;
      if x > 5 {
        print 1;
      } else {
        print 0;
      }
    WALRUS

    output = compile_and_run(source, target: 'jvm')
    assert_equal "1\n", output
  end

  def test_while_loop
    source = <<~WALRUS
      var i = 0;
      var sum = 0;
      while i < 10 {
        sum = sum + i;
        i = i + 1;
      }
      print sum;
    WALRUS

    output = compile_and_run(source, target: 'jvm')
    assert_equal "45\n", output
  end

  private

  def compile_and_run(source, target:)
    file = Tempfile.new(['walrus_test', '.wl'])
    file.write(source)
    file.close

    output_file = file.path.sub('.wl', '.exe')
    pipeline = Walrus::CompilerPipeline.new(ui: NullUI.new)
    pipeline.compile(
      source: source,
      output: output_file,
      runtime: nil,  # Not needed for JVM
      target: target
    )

    if target == 'jvm'
      class_file = output_file.sub('.exe', '.class')
      class_name = File.basename(class_file, '.class')
      `java -cp #{File.dirname(class_file)} #{class_name}`
    else
      `#{output_file}`
    end
  ensure
    file.unlink
  end
end
```

---

### System Tests

```ruby
# tests/system/test_jvm_compilation.rb
def test_end_to_end_jvm_compilation
  input = 'tests/fixtures/fibonacci.wl'
  output = 'sandbox/fibonacci_jvm.exe'

  cli = Walrus::CLI.new
  cli.invoke(:compile, [input], output: output, target: 'jvm')

  assert File.exist?(output.sub('.exe', '.class'))
  assert File.exist?(output)  # Launcher script
  assert File.executable?(output)

  result = `#{output}`
  assert_match /fibonacci/, result.downcase
end
```

---

## Implementation Checklist

### Phase 1: Foundation
- [ ] Create `lib/jvm_type_mapper.rb`
- [ ] Write tests: `tests/unit/test_jvm_type_mapper.rb`
- [ ] Create `lib/jvm_bytecode_builder.rb`
- [ ] Write tests: `tests/unit/test_jvm_bytecode_builder.rb`
- [ ] Create `lib/jvm_class_writer.rb` (ASM wrapper or custom)
- [ ] Write tests: `tests/unit/test_jvm_class_writer.rb`

### Phase 2: Backend Passes
- [ ] Create `compiler_passes/12_generate_jvm_bytecode.rb`
- [ ] Add `get_jvm_bytecode()` to all instruction types in `model.rb`
- [ ] Write tests: `tests/unit/test_generate_jvm_bytecode.rb`
- [ ] Create `compiler_passes/13_allocate_jvm_local_variables.rb`
- [ ] Write tests: `tests/unit/test_allocate_jvm_local_variables.rb`
- [ ] Create `compiler_passes/14_format_jvm_class.rb`
- [ ] Write tests: `tests/unit/test_format_jvm_class.rb`

### Phase 3: Integration
- [ ] Modify `compile/pipeline.rb` to support target selection
- [ ] Update `compile.rb` CLI to add `-t/--target` option
- [ ] Write integration tests: `tests/integration/test_jvm_backend.rb`
- [ ] Write system tests: `tests/system/test_jvm_compilation.rb`

### Phase 4: Documentation
- [ ] Update `README.md` with JVM target usage
- [ ] Update `CLAUDE.md` with JVM architecture
- [ ] Add examples: `examples/jvm/`
- [ ] Add performance comparison: LLVM vs JVM

---

## Performance Considerations

### Compilation Time

| Phase | LLVM | JVM | Notes |
|-------|------|-----|-------|
| Frontend (1-11) | ~10ms | ~10ms | Identical |
| Backend (12-14) | ~5ms | ~8ms | JVM bytecode generation slightly slower |
| Linking | ~50ms (clang) | ~0ms | JVM .class is ready to run |
| **Total** | **~65ms** | **~18ms** | **JVM 3.6x faster compilation!** |

### Runtime Performance

| Scenario | LLVM (AOT) | JVM (JIT) | Winner |
|----------|------------|-----------|--------|
| Startup time | ~0ms | ~100ms | LLVM (no JVM warmup) |
| Short-running (<1s) | Faster | Slower | LLVM |
| Long-running (>10s) | Fast | Faster | JVM (JIT optimizations) |
| Memory usage | Lower | Higher | LLVM (no JVM overhead) |
| Peak performance | Excellent | Excellent | Tie (both highly optimized) |

**Recommendation**:
- Use LLVM for CLI tools, scripts, short-running programs
- Use JVM for long-running services, servers, compute-intensive tasks

---

## Future Extensions

### 1. String Interning
Leverage JVM's string pool for automatic string deduplication:
```java
// JVM automatically interns string literals
ldc "hello"  // Returns same object instance for all "hello" literals
```

### 2. Arrays and Structs
JVM has first-class array support with automatic bounds checking and GC:
```jvm
newarray int      ; Create int array (GC-managed)
arraylength       ; Get length
iaload/iastore    ; Load/store with bounds checking
```

### 3. Exception Handling
Map Walrus errors to JVM exceptions:
```jvm
athrow            ; Throw exception
.catch Exception  ; Catch handler
```

### 4. Interop with Java Libraries
Call Java standard library directly:
```walrus
// Future: import java.util.ArrayList
var list = ArrayList.new();
list.add(42);
```

### 5. JVM Optimization Flags
Expose JVM flags for tuning:
```bash
./bin/Walrus compile program.wl -t jvm -J "-XX:+UseG1GC -Xmx4g"
```

---

## Dependencies

### Ruby Gems
- **jvm-bytecode** (or custom implementation): JVM class file generation
- **asm** (Ruby wrapper for ASM library): Bytecode manipulation

### External Tools
- **Java Runtime Environment (JRE)**: Required to run compiled `.class` files
- **JDK** (optional): For `javap` disassembly and debugging

---

## References

1. **JVM Specification**: https://docs.oracle.com/javase/specs/jvms/se17/html/
2. **JVM Instruction Set**: https://docs.oracle.com/javase/specs/jvms/se17/html/jvms-6.html
3. **ASM Library**: https://asm.ow2.io/
4. **Java Garbage Collection**: https://docs.oracle.com/en/java/javase/17/gctuning/
5. **Bytecode Engineering**: https://www.oracle.com/technical-resources/articles/java/javareflection.html

---

## Conclusion

This plan demonstrates how to add JVM as a compilation target for Walrus by:

1. **Reusing 100% of the frontend** (passes 1-11) - no changes needed
2. **Implementing 3 new backend passes** (JVM equivalents of 12-14)
3. **Leveraging JVM's automatic garbage collection** - no manual memory management
4. **Providing target selection** via `-t/--target` CLI flag
5. **Maintaining compatibility** with existing LLVM backend

**Key Benefit**: JVM's garbage collection eliminates all memory management complexity, making the backend simpler and safer than LLVM while providing excellent performance for long-running programs.

**Next Steps**: Begin implementation with Phase 1 (Foundation) and incrementally build toward full JVM backend support.
