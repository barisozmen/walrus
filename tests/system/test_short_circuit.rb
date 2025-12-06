require_relative '../system_test'

class ShortCircuitTest < SystemTest
  auto_test do |fixture, expected|
    output = compile_and_run(fixture)
    assert_equal expected, output
  end

  TESTCASES = {
    # Test 1: 'and' short-circuits, prevents division by zero
    # x=0, so x!=0 is false, never evaluates 100/x
    'shortcircuit_and.wl' => "Out: 42\n",

    # Test 2: 'or' short-circuits, x==0 is true, never evaluates 100/x
    'shortcircuit_or.wl' => "Out: 7\n",

    # Test 3: Both sides evaluate when needed
    'shortcircuit_both_eval.wl' => "Out: 5\n"
  }

  generate_tests
end
