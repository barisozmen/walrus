require_relative '../test_context'

class TestGenerateWasmGCCode < Minitest::Test
  def setup
    Walrus.reset_context
  end

  # Test simple literal push
  def test_push_integer
    block = BLOCK.new('L0', [PUSH.new(42, type: 'int'), RETURN.new])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 'L0', result.label
    assert_equal 2, result.instructions.length
    assert_equal 'i32.const 42', result.instructions[0].op
    assert_equal 'return', result.instructions[1].op
  end

  # Test arithmetic operations
  def test_add_integers
    block = BLOCK.new('L0', [
      PUSH.new(10, type: 'int'),
      PUSH.new(20, type: 'int'),
      ADD.new,
      RETURN.new
    ])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 4, result.instructions.length
    assert_equal 'i32.const 10', result.instructions[0].op
    assert_equal 'i32.const 20', result.instructions[1].op
    assert_equal 'i32.add', result.instructions[2].op
    assert_equal 'return', result.instructions[3].op
  end

  def test_subtract_integers
    block = BLOCK.new('L0', [
      PUSH.new(100, type: 'int'),
      PUSH.new(30, type: 'int'),
      SUB.new,
      RETURN.new
    ])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 'i32.sub', result.instructions[2].op
  end

  def test_multiply_integers
    block = BLOCK.new('L0', [
      PUSH.new(5, type: 'int'),
      PUSH.new(6, type: 'int'),
      MUL.new,
      RETURN.new
    ])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 'i32.mul', result.instructions[2].op
  end

  def test_divide_integers
    block = BLOCK.new('L0', [
      PUSH.new(20, type: 'int'),
      PUSH.new(4, type: 'int'),
      DIV.new,
      RETURN.new
    ])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 'i32.div_s', result.instructions[2].op
  end

  # Test float operations
  def test_add_floats
    push1 = PUSH.new(20.0)
    push1.type = 'float'
    push2 = PUSH.new(4.0)
    push2.type = 'float'

    block = BLOCK.new('L0', [push1, push2, ADD.new, RETURN.new])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 'f64.const 20.0', result.instructions[0].op
    assert_equal 'f64.const 4.0', result.instructions[1].op
    assert_equal 'f64.add', result.instructions[2].op
  end

  def test_divide_floats
    push1 = PUSH.new(20.0)
    push1.type = 'float'
    push2 = PUSH.new(4.0)
    push2.type = 'float'

    block = BLOCK.new('L0', [push1, push2, DIV.new, RETURN.new])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 'f64.div', result.instructions[2].op
  end

  # Test comparison operations
  def test_less_than
    block = BLOCK.new('L0', [
      PUSH.new(10, type: 'int'),
      PUSH.new(20, type: 'int'),
      LT.new,
      CBRANCH.new('L1', 'L2')
    ])

    result = Walrus::GenerateWasmGCCode.new.run(block)
    assert_equal 'i32.lt_s', result.instructions[2].op
  end

  def test_greater_than
    block = BLOCK.new('L0', [
      PUSH.new(10, type: 'int'),
      PUSH.new(20, type: 'int'),
      GT.new,
      RETURN.new
    ])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 'i32.gt_s', result.instructions[2].op
  end

  def test_equality
    block = BLOCK.new('L0', [
      PUSH.new(10, type: 'int'),
      PUSH.new(20, type: 'int'),
      EQ.new,
      RETURN.new
    ])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 'i32.eq', result.instructions[2].op
  end

  # Test local variable operations
  def test_load_local
    load = LOAD_LOCAL.new('x')
    load.type = 'int'
    block = BLOCK.new('L0', [load, RETURN.new])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 'local.get $x', result.instructions[0].op
  end

  def test_store_local
    block = BLOCK.new('L0', [
      PUSH.new(42, type: 'int'),
      STORE_LOCAL.new('x'),
      PUSH.new(0, type: 'int'),
      RETURN.new
    ])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 'i32.const 42', result.instructions[0].op
    assert_equal 'local.set $x', result.instructions[1].op
  end

  # Test global variable operations
  def test_load_global
    load = LOAD_GLOBAL.new('total')
    load.type = 'int'
    block = BLOCK.new('L0', [load, RETURN.new])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 'global.get $total', result.instructions[0].op
  end

  def test_store_global
    block = BLOCK.new('L0', [
      PUSH.new(100, type: 'int'),
      STORE_GLOBAL.new('total'),
      PUSH.new(0, type: 'int'),
      RETURN.new
    ])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 'i32.const 100', result.instructions[0].op
    assert_equal 'global.set $total', result.instructions[1].op
  end

  # Test control flow markers
  def test_goto
    block = BLOCK.new('L0', [
      PUSH.new(1, type: 'int'),
      STORE_LOCAL.new('x'),
      GOTO.new('L1')
    ])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    last_instr = result.instructions.last
    assert_instance_of WASM_GOTO, last_instr
    assert_equal 'L1', last_instr.label
  end

  def test_cbranch
    block = BLOCK.new('L0', [
      PUSH.new(1, type: 'int'),
      PUSH.new(2, type: 'int'),
      LT.new,
      CBRANCH.new('L1', 'L2')
    ])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    last_instr = result.instructions.last
    assert_instance_of WASM_CBRANCH, last_instr
    assert_equal 'L1', last_instr.true_label
    assert_equal 'L2', last_instr.false_label
  end

  # Test print operation
  def test_print_integer
    block = BLOCK.new('L0', [
      PUSH.new(42, type: 'int'),
      PRINT.new,
      PUSH.new(0, type: 'int'),
      RETURN.new
    ])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    # PRINT generates call and drop
    print_instrs = result.instructions[1..2]
    assert_equal 'call $_print_int', print_instrs[0].op
    assert_equal 'drop', print_instrs[1].op
  end

  # Test function call
  def test_function_call
    call = CALL.new('fact', 1)
    call.type = 'int'

    block = BLOCK.new('L0', [
      PUSH.new(10, type: 'int'),
      call,
      RETURN.new
    ])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 'i32.const 10', result.instructions[0].op
    assert_equal 'call $fact', result.instructions[1].op
  end

  # Test unary negation
  def test_negation_integer
    block = BLOCK.new('L0', [
      PUSH.new(5, type: 'int'),
      NEG.new,
      RETURN.new
    ])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    # Integer negation generates i32.const -1 and i32.mul
    # The exact implementation may vary, but we should end up with negated value
    assert result.instructions.length >= 3
  end

  # Test logical NOT
  def test_logical_not
    block = BLOCK.new('L0', [
      PUSH.new(1, type: 'bool'),
      NOT.new,
      RETURN.new
    ])
    result = Walrus::GenerateWasmGCCode.new.run(block)

    assert_equal 'i32.eqz', result.instructions[1].op
  end
end
