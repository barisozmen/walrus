#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../system_test'

class OptionalValueTest < SystemTest
  auto_test do |fixture, expected|
    output = compile_and_run(fixture)
    assert_equal expected, output
  end

  TESTCASES = {
    'demo_optional_value.wl' => <<~OUT,
      Out: 42
      Out: 0
      Out: 100
    OUT

    'test_optional_complete.wl' => <<~OUT,
      Out: 10
      Out: 0
      Out: 10
      Out: 15
    OUT

    'optvalue.wl' => <<~OUT,
      Out: 0
      Out: 123
      Out: 123
    OUT
  }

  generate_tests
end
