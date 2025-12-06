#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../system_test'
require 'open3'

class LineNumbersTest < SystemTest
  auto_test do |fixture, expected_line|
    source = File.join(FIXTURES, fixture)
    stdout, stderr, status = Open3.capture3("#{COMPILER} compile #{source}")

    refute status.success?, "Expected compilation to fail"

    line_match = stderr.match(/at (?:<source> at )?(\d+):\d+/)
    assert line_match, "Error should contain line number"

    actual_line = line_match[1].to_i
    assert_equal expected_line, actual_line
  end

  TESTCASES = {
    'bad_syntax_line3.wl' => 3,
    'bad_syntax_line5.wl' => 5
  }

  generate_tests
end
