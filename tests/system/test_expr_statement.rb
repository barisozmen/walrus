#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../system_test'

class ExprStatementTest < SystemTest
  auto_test do |fixture, expected|
    output = compile_and_run(fixture)
    assert_equal expected, output
  end

  TESTCASES = {
    'exprstatement.wl' => <<~OUT,
      Out: 5
      Out: 9
    OUT

    'expr_stmt_side_effects.wl' => <<~OUT,
      Out: 3
    OUT

    'expr_stmt_mixed.wl' => <<~OUT,
      Out: 30
      Out: 30
    OUT
  }

  generate_tests
end
