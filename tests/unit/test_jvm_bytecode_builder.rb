require_relative '../test_context'
require_relative '../../lib/jvm_bytecode_builder'

class TestJVMBytecodeBuilder < Minitest::Test
  include Walrus

  def test_push_int_constants
    builder = JVMBytecodeBuilder.new

    # iconst_X for 0-5
    builder.push_int(0)
    assert_equal :iconst_0, builder.instructions[0].opcode

    builder.push_int(5)
    assert_equal :iconst_5, builder.instructions[1].opcode

    # bipush for small values
    builder.push_int(42)
    assert_equal :bipush, builder.instructions[2].opcode
    assert_equal [42], builder.instructions[2].operands

    # sipush for larger values
    builder.push_int(1000)
    assert_equal :sipush, builder.instructions[3].opcode

    # ldc for even larger values
    builder.push_int(100000)
    assert_equal :ldc, builder.instructions[4].opcode
  end

  def test_push_double
    builder = JVMBytecodeBuilder.new

    builder.push_double(0.0)
    assert_equal :dconst_0, builder.instructions[0].opcode

    builder.push_double(1.0)
    assert_equal :dconst_1, builder.instructions[1].opcode

    builder.push_double(3.14)
    assert_equal :ldc2_w, builder.instructions[2].opcode
    assert_equal [3.14], builder.instructions[2].operands
  end

  def test_arithmetic_operations
    builder = JVMBytecodeBuilder.new

    builder.iadd
    assert_equal :iadd, builder.instructions[0].opcode

    builder.dadd
    assert_equal :dadd, builder.instructions[1].opcode

    builder.isub
    assert_equal :isub, builder.instructions[2].opcode

    builder.imul
    assert_equal :imul, builder.instructions[3].opcode

    builder.idiv
    assert_equal :idiv, builder.instructions[4].opcode
  end

  def test_local_variable_load_store
    builder = JVMBytecodeBuilder.new

    # Test iload optimization
    builder.iload(0)
    assert_equal :iload_0, builder.instructions[0].opcode

    builder.iload(3)
    assert_equal :iload_3, builder.instructions[1].opcode

    builder.iload(5)
    assert_equal :iload, builder.instructions[2].opcode
    assert_equal [5], builder.instructions[2].operands

    # Test istore
    builder.istore(0)
    assert_equal :istore_0, builder.instructions[3].opcode

    builder.istore(10)
    assert_equal :istore, builder.instructions[4].opcode
    assert_equal [10], builder.instructions[4].operands
  end

  def test_comparisons
    builder = JVMBytecodeBuilder.new

    builder.if_icmplt('L1')
    assert_equal :if_icmplt, builder.instructions[0].opcode
    assert_equal ['L1'], builder.instructions[0].operands

    builder.if_icmpgt('L2')
    assert_equal :if_icmpgt, builder.instructions[1].opcode

    builder.if_icmpeq('L3')
    assert_equal :if_icmpeq, builder.instructions[2].opcode
  end

  def test_control_flow
    builder = JVMBytecodeBuilder.new

    builder.goto('L1')
    assert_equal :goto, builder.instructions[0].opcode
    assert_equal ['L1'], builder.instructions[0].operands

    builder.ifeq('L2')
    assert_equal :ifeq, builder.instructions[1].opcode

    builder.ifne('L3')
    assert_equal :ifne, builder.instructions[2].opcode
  end

  def test_return_instructions
    builder = JVMBytecodeBuilder.new

    builder.ireturn
    assert_equal :ireturn, builder.instructions[0].opcode

    builder.dreturn
    assert_equal :dreturn, builder.instructions[1].opcode

    builder.areturn
    assert_equal :areturn, builder.instructions[2].opcode

    builder.voidreturn
    assert_equal :return, builder.instructions[3].opcode
  end

  def test_stack_depth_tracking
    builder = JVMBytecodeBuilder.new

    assert_equal 0, builder.max_stack

    # Push increases stack
    builder.push_int(10)
    assert_equal 1, builder.max_stack

    builder.push_int(20)
    assert_equal 2, builder.max_stack

    # Add decreases by 1
    builder.iadd
    assert_equal 2, builder.max_stack  # Max remains 2

    # Return clears stack
    builder.ireturn
    assert_equal 2, builder.max_stack  # Max stays at peak
  end

  def test_label_generation
    builder = JVMBytecodeBuilder.new

    label1 = builder.gen_label('TEST')
    label2 = builder.gen_label('TEST')

    assert_equal 'TEST1', label1
    assert_equal 'TEST2', label2
    refute_equal label1, label2
  end

  def test_label_instruction
    builder = JVMBytecodeBuilder.new

    builder.label('L1')
    assert_equal :label, builder.instructions[0].opcode
    assert_equal ['L1'], builder.instructions[0].operands
  end

  def test_method_invocation
    builder = JVMBytecodeBuilder.new

    builder.invokestatic('MyClass', 'myMethod', '(I)I')
    assert_equal :invokestatic, builder.instructions[0].opcode
    assert_equal ['MyClass.myMethod', '(I)I'], builder.instructions[0].operands

    builder.invokevirtual('java/io/PrintStream', 'println', '(I)V')
    assert_equal :invokevirtual, builder.instructions[1].opcode
  end

  def test_static_fields
    builder = JVMBytecodeBuilder.new

    builder.getstatic('MyClass', 'myField', 'I')
    assert_equal :getstatic, builder.instructions[0].opcode
    assert_equal ['MyClass.myField', 'I'], builder.instructions[0].operands

    builder.putstatic('MyClass', 'myField', 'I')
    assert_equal :putstatic, builder.instructions[1].opcode
  end

  def test_stack_manipulation
    builder = JVMBytecodeBuilder.new

    builder.dup
    assert_equal :dup, builder.instructions[0].opcode

    builder.pop
    assert_equal :pop, builder.instructions[1].opcode

    builder.swap
    assert_equal :swap, builder.instructions[2].opcode
  end

  def test_type_conversions
    builder = JVMBytecodeBuilder.new

    builder.i2d
    assert_equal :i2d, builder.instructions[0].opcode

    builder.d2i
    assert_equal :d2i, builder.instructions[1].opcode
  end

  def test_complex_stack_depth_calculation
    builder = JVMBytecodeBuilder.new

    # Simulate: 10 + 20 + 30
    builder.push_int(10)   # Stack: [10]
    builder.push_int(20)   # Stack: [10, 20]
    builder.iadd           # Stack: [30]
    builder.push_int(30)   # Stack: [30, 30]
    builder.iadd           # Stack: [60]

    assert_equal 2, builder.max_stack  # Max was 2 when we had [10, 20]
  end

  def test_double_stack_depth
    builder = JVMBytecodeBuilder.new

    # Doubles take 2 stack slots
    builder.push_double(1.5)   # Stack depth: +2
    assert builder.max_stack >= 2

    builder.push_double(2.5)   # Stack depth: +2 (total 4)
    assert builder.max_stack >= 4

    builder.dadd               # Stack depth: -2 (total 2)
    assert_equal 4, builder.max_stack  # Peak was 4
  end
end
