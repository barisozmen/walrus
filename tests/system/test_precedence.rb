require_relative '../system_test'

class PrecedenceTest < SystemTest
  auto_test do |fixture, expected|
    output = compile_and_run(fixture)
    assert_equal expected, output
  end

  TESTCASES = {
    'precedence.wl' => "Out: 14\nOut: 10\nOut: 1\nOut: -5\nOut: 10\n",
    'precedence_chain.wl' => "Out: 10\nOut: 24\nOut: 65\nOut: 10\nOut: 95\nOut: 50\n",
    'precedence_complex.wl' => "Out: 16\nOut: 30\nOut: 62\nOut: 23\nOut: 11\nOut: 0\n"
  }

  generate_tests
end
