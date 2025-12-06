#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../system_test'
require 'open3'

class AssignmentInConditionalTest < SystemTest
  auto_test do |fixture, expected_message|
    source = File.join(FIXTURES, fixture)
    stdout, stderr, status = Open3.capture3("#{COMPILER} compile #{source}")

    refute status.success?, "Expected compilation to fail for assignment in conditional"

    assert_match expected_message, stderr,
                 "Error message should suggest using '==' instead of '='"
  end

  TESTCASES = {
    'assignment_in_if.wl' => /Did you mean '==' instead of '='?/,
    'assignment_in_while.wl' => /Did you mean '==' instead of '='?/,
    'assignment_in_if_line3.wl' => /at 3:\d+.*Did you mean '==' instead of '='?/im
  }

  generate_tests

  # Positive test: valid comparisons should still work
  def test_valid_comparison_compiles
    output = compile_and_run('valid_comparison.wl')
    assert_equal "Out: 1\nOut: 0\n", output
  end
end
