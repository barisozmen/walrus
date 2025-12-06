require_relative "../test_context"

# Unit test: EQ/NE instructions must generate fcmp for floats, icmp for ints
class TestFloatEqualityComparison < Minitest::Test

  def test_eq_generates_fcmp_oeq_for_double_operands
    # Simulate: two double values on stack, EQ should generate fcmp oeq
    stack = ['%.1', '%.2']
    type_map = { '%.1' => 'double', '%.2' => 'double' }

    eq_instr = EQ.new
    llvm = eq_instr.get_llvm_code(stack, type_map)

    assert_match(/fcmp oeq double/, llvm.op, "EQ with double must use fcmp oeq")
    refute_match(/icmp eq double/, llvm.op, "EQ with double must NOT use icmp")
  end

  def test_ne_generates_fcmp_one_for_double_operands
    # Simulate: two double values on stack, NE should generate fcmp one
    stack = ['%.1', '%.2']
    type_map = { '%.1' => 'double', '%.2' => 'double' }

    ne_instr = NE.new
    llvm = ne_instr.get_llvm_code(stack, type_map)

    assert_match(/fcmp one double/, llvm.op, "NE with double must use fcmp one")
    refute_match(/icmp ne double/, llvm.op, "NE with double must NOT use icmp")
  end

  def test_eq_still_generates_icmp_for_i32_operands
    # Simulate: two i32 values on stack, EQ should still use icmp
    stack = ['%.1', '%.2']
    type_map = { '%.1' => 'i32', '%.2' => 'i32' }

    eq_instr = EQ.new
    llvm = eq_instr.get_llvm_code(stack, type_map)

    assert_match(/icmp eq i32/, llvm.op, "EQ with i32 must use icmp eq")
    refute_match(/fcmp/, llvm.op, "EQ with i32 must NOT use fcmp")
  end

  def test_ne_still_generates_icmp_for_i32_operands
    # Simulate: two i32 values on stack, NE should still use icmp
    stack = ['%.1', '%.2']
    type_map = { '%.1' => 'i32', '%.2' => 'i32' }

    ne_instr = NE.new
    llvm = ne_instr.get_llvm_code(stack, type_map)

    assert_match(/icmp ne i32/, llvm.op, "NE with i32 must use icmp ne")
    refute_match(/fcmp/, llvm.op, "NE with i32 must NOT use fcmp")
  end
end
