#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../system_test'
require 'open3'

class ErrorMessagesTest < SystemTest
  auto_test do |fixture, expectations|
    source = File.join(FIXTURES, fixture)
    stdout, stderr, status = Open3.capture3("#{COMPILER} compile #{source}")
    output = stdout + stderr

    refute status.success?, "Expected compilation to fail for #{fixture}"

    # Assert line and column number are present in new format (at 2:3)
    assert_match(/at #{expectations[:line]}:#{expectations[:column]}/, output,
                 "Expected error to contain 'at #{expectations[:line]}:#{expectations[:column]}'")

    # Assert source line is shown (check for pipe separator)
    assert_match(/#{expectations[:line]} \|/, output,
                 "Expected error to show source line with '#{expectations[:line]} |'")

    # Assert caret pointer is present
    assert_match(/\^/, output,
                 "Expected error to show caret (^) pointing to error location")

    # Assert hint is present (if expected)
    if expectations[:hint]
      assert_match(/Hint:/, output,
                   "Expected error to show a hint")
    end

    # Assert contextual keywords are present
    expectations[:keywords].each do |keyword|
      assert_match(/#{Regexp.escape(keyword)}/i, output,
                   "Expected error to mention '#{keyword}'")
    end
  end

  TESTCASES = {
    'error_type_mismatch.wl' => {
      line: 3,
      column: 9,
      keywords: ['type', 'int', 'float'],
      hint: true
    },
    'error_unknown_var.wl' => {
      line: 2,
      column: 7,
      keywords: ['unknown', 'variable'],
      hint: false
    },
    'error_comparison_types.wl' => {
      line: 3,
      column: 6,
      keywords: ['type', 'int', 'float'],
      hint: true
    },
    'error_wrong_func_args.wl' => {
      line: 5,
      column: 18,
      keywords: ['expects', 'arguments'],
      hint: false
    },
    'error_assignment_type.wl' => {
      line: 2,
      column: 3,
      keywords: ['assign', 'float', 'int'],
      hint: true
    }
  }

  generate_tests
end
