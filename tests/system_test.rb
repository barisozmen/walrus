#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'

class SystemTest < Minitest::Test
  FIXTURES = File.expand_path('fixtures', __dir__)
  COMPILER = File.expand_path('../bin/Walrus', __dir__)

  def self.auto_test(&block)
    define_method(:run_test, &block)
  end

  def self.generate_tests
    self::TESTCASES.each_with_index do |(fixture, expected), idx|
      test_name = "test_#{idx}_#{fixture.gsub(/[^a-z0-9]/i, '_')}"
      define_method(test_name) do
        run_test(fixture, expected)
      end
    end
  end

  private

  def compile_and_run(fixture)
    source = File.join(self.class::FIXTURES, fixture)
    stdout, stderr, status = Open3.capture3("#{self.class::COMPILER} compile #{source} -o out.exe")
    assert status.success?, "Compilation failed:\n#{stderr}"

    stdout, stderr, status = Open3.capture3('./out.exe')
    assert status.success?, "Execution failed:\n#{stderr}"

    stdout
  ensure
    File.delete('out.exe') if File.exist?('out.exe')
    File.delete('out.ll') if File.exist?('out.ll')
  end
end
