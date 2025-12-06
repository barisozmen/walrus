#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../system_test'

class ElsIfAndCaseTest < SystemTest
  auto_test do |fixture, expected_output|
    output = compile_and_run(fixture)
    assert_equal expected_output, output
  end

  TESTCASES = {
    'elsif_simple.wl' => "Out: 0\n",
    'elsif_chain.wl' => "Out: 2\n",
    'elsif_no_else.wl' => "Out: 1\n",
    'case_simple.wl' => "Out: 200\n",
    'case_no_match.wl' => "Out: 999\n",
    'elsif_case_nested.wl' => "Out: 220\n"
  }

  generate_tests
end
