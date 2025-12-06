require_relative '../system_test'

class ForLoopTest < SystemTest
  auto_test do |fixture, expected|
    output = compile_and_run(fixture)
    assert_equal expected, output
  end

  TESTCASES = {
    'forloop.wl' => "Out: 45\n",
    'nested_forloop.wl' => "Out: 0\nOut: 1\nOut: 2\nOut: 10\nOut: 11\nOut: 12\nOut: 20\nOut: 21\nOut: 22\n"
  }

  generate_tests
end
