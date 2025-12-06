#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../system_test'

class OptionalElseTest < SystemTest
  auto_test do |fixture, expected|
    output = compile_and_run(fixture)
    assert_equal expected, output
  end

  TESTCASES = {
    'optelse.wl' => <<~OUT,
      Out: 2
      Out: 2
    OUT

    'optelse_comprehensive.wl' => <<~OUT,
      Out: 5
      Out: 3
      Out: 20
      Out: 30
      Out: -1
      Out: 0
      Out: 1
    OUT
  }

  generate_tests
end
