#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../system_test'

class TypeSpecifiersTest < SystemTest
  auto_test do |fixture, expected|
    output = compile_and_run(fixture)
    assert_equal expected, output
  end

  TESTCASES = {
    'specifier.wl' => <<~OUT,
      Out: 16
    OUT

    'fact.wl' => <<~OUT,
      Out: 1
      Out: 2
      Out: 6
      Out: 24
      Out: 120
      Out: 720
      Out: 5040
      Out: 40320
      Out: 362880
    OUT

    'fib.wl' => <<~OUT,
      Out: 1
      Out: 1
      Out: 2
      Out: 3
      Out: 5
      Out: 8
      Out: 13
      Out: 21
      Out: 34
      Out: 55
      Out: 89
      Out: 144
      Out: 233
      Out: 377
      Out: 610
      Out: 987
      Out: 1597
      Out: 2584
      Out: 4181
      Out: 6765
      Out: 10946
      Out: 17711
      Out: 28657
      Out: 46368
      Out: 75025
      Out: 121393
      Out: 196418
      Out: 317811
      Out: 514229
      Out: 832040
    OUT
  }

  generate_tests
end
