require_relative "../system_test"

# System test: sqrt.wl must compile and run correctly
class TestSqrtFixture < SystemTest
  auto_test do |fixture, expected|
    output = compile_and_run(fixture)
    assert_equal expected, output
  end

  TESTCASES = {
    'sqrt.wl' => <<~OUT
      Out: 0
      Out: 1
      Out: 1.41421
      Out: 1.73205
      Out: 2
      Out: 2.23607
      Out: 2.44949
      Out: 2.64575
      Out: 2.82843
      Out: 3
      Out: 3.16228
    OUT
  }

  generate_tests
end
