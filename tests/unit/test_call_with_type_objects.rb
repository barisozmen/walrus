require_relative "../test_context"

# Unit test: CALL instruction param_types might be Type objects, not strings
class TestCallWithTypeObjects < Minitest::Test

  def test_call_handles_type_objects_not_just_strings
    # This simulates what actually happens in the compiler:
    # param_types gets set from node.args.map(&:type) which may be Type objects

    # Create a mock type class to simulate what happens in real code
    type_float = Object.new
    def type_float.to_s; 'float'; end

    stack = ['%.1', '%.2']
    type_map = { '%.1' => 'double', '%.2' => 'double' }

    call_instr = CALL.new('fabs', 1, type: 'float')
    call_instr.param_types = [type_float]  # Type object, not string!

    llvm = call_instr.get_llvm_code(stack, type_map)

    # Should generate call with double (because type_float represents float)
    assert_match(/call double \(double\) @fabs\(double/, llvm.op,
                 "CALL must handle Type objects by calling to_s")
  end
end
