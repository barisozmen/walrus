require_relative "../test_context"

# Unit test: CALL instruction must generate correct LLVM call with proper types
class TestCallInstructionLlvmGeneration < Minitest::Test

  def test_call_uses_function_signature_types_from_context
    # Simulate: calling a function that takes 2 doubles and returns double
    stack = ['%.1', '%.2']  # Two arguments on stack
    type_map = { '%.1' => 'double', '%.2' => 'double' }

    # CALL instruction with param_types and return type
    call_instr = CALL.new('add', 2, type: 'float')
    call_instr.param_types = ['float', 'float']

    llvm = call_instr.get_llvm_code(stack, type_map)

    # Should generate call with double signature (args may be in any order due to stack pop/reverse)
    assert_match(/%.+ = call double \(double, double\) @add\(double %.+, double %.+\)/, llvm.op,
                 "CALL must use double types from param_types")

    # Result register should be tracked as double
    assert_equal 'double', type_map[stack.last], "Result should be double type"
  end

  def test_call_pops_arguments_from_stack_and_pushes_result
    stack = ['%.1', '%.2', '%.3']
    type_map = { '%.1' => 'i32', '%.2' => 'i32', '%.3' => 'i32' }

    call_instr = CALL.new('add', 2)  # Call with 2 arguments
    llvm = call_instr.get_llvm_code(stack, type_map)

    # Should pop 2 arguments and push result (register number may vary)
    assert_equal 2, stack.length, "CALL must leave 2 items on stack (popped 2, pushed 1)"
    assert_equal '%.1', stack.first, "Bottom of stack should be unchanged"
    assert stack.last.start_with?('%.'), "Result should be a register"
    assert llvm.op.include?('@add'), "CALL must reference function name"
  end

  def test_call_generates_correct_llvm_format
    stack = ['%.1', '%.2']
    type_map = { '%.1' => 'i32', '%.2' => 'i32' }

    call_instr = CALL.new('multiply', 2)
    llvm = call_instr.get_llvm_code(stack, type_map)

    # Should generate: %.N = call returntype @funcname(argtype arg1, argtype arg2)
    assert_match(/%.+ = call .+ @multiply\(.+, .+\)/, llvm.op,
                 "CALL must generate proper LLVM call format")
  end
end
