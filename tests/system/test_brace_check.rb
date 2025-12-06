#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../system_test'
require 'open3'

class BalancedBracesTest < SystemTest
  auto_test do |fixture, expected_error_pattern|
    source = File.join(FIXTURES, fixture)
    stdout, stderr, status = Open3.capture3("#{COMPILER} compile #{source}")

    refute status.success?, "Expected compilation to fail for #{fixture}"
    assert_match expected_error_pattern, stderr, "Error message should match pattern"
  end

  TESTCASES = {
    'badbrace.wl' => /at 5:\d+.*no opening/im,
    'badparen.wl' => /at 3:\d+.*no closing/im
  }

  generate_tests
end
