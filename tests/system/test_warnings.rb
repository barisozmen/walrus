#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../system_test'
require 'open3'

class WarningsTest < SystemTest
  auto_test do |fixture, expectations|
    source = File.join(FIXTURES, 'warnings', fixture)
    stdout, stderr, status = Open3.capture3("#{COMPILER} compile #{source}")
    output = stdout + stderr

    # Compilation should succeed (warnings are non-fatal)
    assert status.success?, "Expected compilation to succeed for #{fixture}"

    # Check if warnings section is present (or absent)
    if expectations[:has_warnings]
      assert_match(/== Warnings/, output,
                   "Expected '== Warnings' section to be present")
      assert_match(/Unused variable/, output,
                   "Expected 'Unused variable' text in warnings")
    else
      refute_match(/== Warnings/, output,
                   "Expected no '== Warnings' section")
      refute_match(/Unused variable/, output,
                   "Expected no 'Unused variable' warnings")
    end

    # Compilation should always succeed
    assert_match(/== Success!/, output,
                 "Expected compilation success message")
    assert_match(/Compilation completed successfully/, output,
                 "Expected 'Compilation completed successfully' message")
  end

  TESTCASES = {
    'unused_variables.wl' => {
      has_warnings: true
    },
    'no_warnings.wl' => {
      has_warnings: false
    }
  }

  generate_tests
end
