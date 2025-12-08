require_relative '../test_context'

class TestGenerateJVMBytecode < Minitest::Test
  def setup
    # Reset context for each test
    Walrus.reset_context
    Walrus.context[:class_name] = 'TestClass'
  end

  def test_simple_arithmetic
    func = Function.new('test', [], [
      BLOCK.new('L0', [
        PUSH.new(10, type: 'int'),
        PUSH.new(20, type: 'int'),
        ADD.new,
        RETURN.new
      ])
    ], type: 'int')

    # First allocate locals
    context = Walrus.context.merge(local_var_maps: {}, max_locals_map: {})
    Walrus::AllocateJVMLocalVariables.new.transform_function(func, context)

    # Then generate bytecode
    pass = Walrus::GenerateJVMBytecode.new
    pass.transform_function(func, context)

    builder = context[:jvm_builders]['test']
    refute_nil builder

    instructions = builder.instructions
    # Should have: label, bipush 10, bipush 20, iadd, ireturn
    assert instructions.any? { |i| i.opcode == :label && i.operands == ['L0'] }
    assert instructions.any? { |i| i.opcode == :bipush && i.operands == [10] }
    assert instructions.any? { |i| i.opcode == :bipush && i.operands == [20] }
    assert instructions.any? { |i| i.opcode == :iadd }
    assert instructions.any? { |i| i.opcode == :ireturn }
  end

  def test_local_variable_load_store
    func = Function.new('test', [], [
      BLOCK.new('L0', [
        LOCAL.new('x', type: 'int'),
        PUSH.new(42, type: 'int'),
        STORE_LOCAL.new('x', type: 'int'),
        LOAD_LOCAL.new('x', type: 'int'),
        RETURN.new
      ])
    ], type: 'int')

    context = Walrus.context.merge(local_var_maps: {}, max_locals_map: {})
    Walrus::AllocateJVMLocalVariables.new.transform_function(func, context)

    pass = Walrus::GenerateJVMBytecode.new
    pass.transform_function(func, context)

    builder = context[:jvm_builders]['test']
    instructions = builder.instructions

    # Should have: bipush 42, istore_0, iload_0, ireturn
    assert instructions.any? { |i| i.opcode == :bipush && i.operands == [42] }
    assert instructions.any? { |i| i.opcode == :istore_0 }
    assert instructions.any? { |i| i.opcode == :iload_0 }
    assert instructions.any? { |i| i.opcode == :ireturn }
  end

  def test_comparison_generates_labels
    func = Function.new('test', [], [
      BLOCK.new('L0', [
        PUSH.new(10, type: 'int'),
        PUSH.new(20, type: 'int'),
        LT.new,
        RETURN.new
      ])
    ], type: 'int')

    context = Walrus.context.merge(local_var_maps: {}, max_locals_map: {})
    Walrus::AllocateJVMLocalVariables.new.transform_function(func, context)

    pass = Walrus::GenerateJVMBytecode.new
    pass.transform_function(func, context)

    builder = context[:jvm_builders]['test']
    instructions = builder.instructions

    # Comparison should generate: if_icmplt, labels, push 0/1, goto
    assert instructions.any? { |i| i.opcode == :if_icmplt }
    assert instructions.any? { |i| i.opcode == :goto }

    # Should push boolean results (0 or 1)
    iconst_count = instructions.count { |i| i.opcode == :iconst_0 || i.opcode == :iconst_1 }
    assert iconst_count >= 1, "Should push boolean result"
  end

  def test_double_arithmetic
    func = Function.new('test', [], [
      BLOCK.new('L0', [
        PUSH.new(1.5, type: 'float'),
        PUSH.new(2.5, type: 'float'),
        ADD.new,
        RETURN.new
      ])
    ], type: 'float')

    context = Walrus.context.merge(local_var_maps: {}, max_locals_map: {})
    Walrus::AllocateJVMLocalVariables.new.transform_function(func, context)

    pass = Walrus::GenerateJVMBytecode.new
    pass.transform_function(func, context)

    builder = context[:jvm_builders]['test']
    instructions = builder.instructions

    # Should use double operations
    assert instructions.any? { |i| i.opcode == :ldc2_w && i.operands == [1.5] }
    assert instructions.any? { |i| i.opcode == :ldc2_w && i.operands == [2.5] }
    assert instructions.any? { |i| i.opcode == :dadd }
    assert instructions.any? { |i| i.opcode == :dreturn }
  end

  def test_control_flow_instructions
    func = Function.new('test', [], [
      BLOCK.new('L0', [GOTO.new('L1')]),
      BLOCK.new('L1', [PUSH.new(1, type: 'int'), RETURN.new])
    ], type: 'int')

    context = Walrus.context.merge(local_var_maps: {}, max_locals_map: {})
    Walrus::AllocateJVMLocalVariables.new.transform_function(func, context)

    pass = Walrus::GenerateJVMBytecode.new
    pass.transform_function(func, context)

    builder = context[:jvm_builders]['test']
    instructions = builder.instructions

    # Should have labels and goto
    assert instructions.any? { |i| i.opcode == :label && i.operands == ['L0'] }
    assert instructions.any? { |i| i.opcode == :label && i.operands == ['L1'] }
    assert instructions.any? { |i| i.opcode == :goto && i.operands == ['L1'] }
  end

  def test_cbranch_instruction
    func = Function.new('test', [], [
      BLOCK.new('L0', [
        PUSH.new(1, type: 'int'),
        CBRANCH.new('L1', 'L2')
      ]),
      BLOCK.new('L1', [PUSH.new(10, type: 'int'), RETURN.new]),
      BLOCK.new('L2', [PUSH.new(20, type: 'int'), RETURN.new])
    ], type: 'int')

    context = Walrus.context.merge(local_var_maps: {}, max_locals_map: {})
    Walrus::AllocateJVMLocalVariables.new.transform_function(func, context)

    pass = Walrus::GenerateJVMBytecode.new
    pass.transform_function(func, context)

    builder = context[:jvm_builders]['test']
    instructions = builder.instructions

    # CBRANCH should generate ifne + goto
    assert instructions.any? { |i| i.opcode == :ifne && i.operands == ['L1'] }
    assert instructions.any? { |i| i.opcode == :goto && i.operands == ['L2'] }
  end

  def test_negation
    func = Function.new('test', [], [
      BLOCK.new('L0', [
        PUSH.new(42, type: 'int'),
        NEG.new,
        RETURN.new
      ])
    ], type: 'int')

    context = Walrus.context.merge(local_var_maps: {}, max_locals_map: {})
    Walrus::AllocateJVMLocalVariables.new.transform_function(func, context)

    pass = Walrus::GenerateJVMBytecode.new
    pass.transform_function(func, context)

    builder = context[:jvm_builders]['test']
    instructions = builder.instructions

    assert instructions.any? { |i| i.opcode == :ineg }
  end

  def test_stack_depth_calculated
    func = Function.new('test', [], [
      BLOCK.new('L0', [
        PUSH.new(1, type: 'int'),
        PUSH.new(2, type: 'int'),
        PUSH.new(3, type: 'int'),
        ADD.new,
        ADD.new,
        RETURN.new
      ])
    ], type: 'int')

    context = Walrus.context.merge(local_var_maps: {}, max_locals_map: {})
    Walrus::AllocateJVMLocalVariables.new.transform_function(func, context)

    pass = Walrus::GenerateJVMBytecode.new
    pass.transform_function(func, context)

    builder = context[:jvm_builders]['test']

    # Max stack should be at least 3 (when we have 3 values on stack)
    assert builder.max_stack >= 3, "Max stack should be at least 3, got #{builder.max_stack}"
  end
end
