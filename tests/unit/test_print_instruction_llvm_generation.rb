require_relative "../test_context"

# Unit test: PRINT instruction must generate correct LLVM call based on stack type
class TestPrintInstructionLlvmGeneration < Minitest::Test

  def test_print_generates_print_float_for_double_on_stack
    # Simulate: stack has a double value, PRINT should call @_print_float
    stack = ['%.1']
    type_map = { '%.1' => 'double' }

    print_instr = PRINT.new
    llvm = print_instr.get_llvm_code(stack, type_map)

    assert_match(/@_print_float/, llvm.op, "PRINT with double on stack must generate @_print_float call")
    assert_match(/double/, llvm.op, "Must use double type in call")
    refute_match(/@_print_int/, llvm.op, "Must NOT generate @_print_int call")
  end

  def test_print_generates_print_int_for_i32_on_stack
    # Simulate: stack has an i32 value, PRINT should call @_print_int
    stack = ['%.1']
    type_map = { '%.1' => 'i32' }

    print_instr = PRINT.new
    llvm = print_instr.get_llvm_code(stack, type_map)

    assert_match(/@_print_int/, llvm.op, "PRINT with i32 on stack must generate @_print_int call")
    assert_match(/i32/, llvm.op, "Must use i32 type in call")
    refute_match(/@_print_float/, llvm.op, "Must NOT generate @_print_float call")
  end

  def test_print_defaults_to_print_int_when_type_unknown
    # Simulate: stack has a value but type is not in type_map
    stack = ['%.1']
    type_map = {}

    print_instr = PRINT.new
    llvm = print_instr.get_llvm_code(stack, type_map)

    # Should default to @_print_int for backward compatibility
    assert_match(/@_print_int/, llvm.op, "PRINT with unknown type should default to @_print_int")
  end

  def test_print_pops_value_from_stack
    # Simulate: stack has multiple values
    stack = ['%.1', '%.2', '%.3']
    type_map = { '%.3' => 'double' }

    print_instr = PRINT.new
    llvm = print_instr.get_llvm_code(stack, type_map)

    # Stack should have top value popped
    assert_equal ['%.1', '%.2'], stack, "PRINT must pop the top value from stack"
    assert_match(/%.3/, llvm.op, "PRINT must use the popped value in the call")
  end
end
