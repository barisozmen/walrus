#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../system_test'
require 'open3'

class OptionalReturnTypesTest < SystemTest
  # Test successful compilation and execution
  def test_optional_return_simple_cases
    output = compile_and_run('optional_return.wl')
    expected = <<~OUT
      Out: 25
      Out: 20
      Out: 7
      Out: 3
      Out: 14
      Out: 6.25
    OUT
    assert_equal expected, output
  end

  # Test that error case fails with correct error message
  def test_inconsistent_return_types_error
    source = File.join(FIXTURES, 'error_inconsistent_returns.wl')
    stdout, stderr, status = Open3.capture3("#{COMPILER} compile #{source}")
    output = stdout + stderr

    refute status.success?, "Expected compilation to fail for inconsistent return types"

    # Assert error mentions inconsistent types
    assert_match(/inconsistent return types/i, output,
                 "Expected error to mention 'inconsistent return types'")

    # Assert error shows both conflicting types
    assert_match(/int/, output, "Expected error to mention 'int'")
    assert_match(/float/, output, "Expected error to mention 'float'")

    # Assert function name is in error
    assert_match(/bad/, output, "Expected error to mention function name 'bad'")

    # Assert location info is present (line 7 is where the float return is)
    assert_match(/at 7:/, output, "Expected error to show line 7")

    # Assert hint is present
    assert_match(/Hint:/, output, "Expected error to show a hint")
    assert_match(/same type/i, output, "Expected hint to mention 'same type'")
  end

  # Test explicit return types still work (backward compatibility)
  def test_explicit_return_types_still_work
    # Create a temporary test file with explicit return types
    test_code = <<~Walrus
      func add(a int, b int) int {
          return a + b;
      }

      func multiply(x float, y float) float {
          return x * y;
      }

      print add(10, 5);
      print multiply(2.5, 4.0);
    Walrus

    File.write('/tmp/explicit_return_test.wl', test_code)

    begin
      stdout, stderr, status = Open3.capture3("#{COMPILER} compile /tmp/explicit_return_test.wl -o out.exe")
      assert status.success?, "Explicit return types should still compile: #{stderr}"

      stdout, stderr, status = Open3.capture3('./out.exe')
      assert status.success?, "Execution should succeed: #{stderr}"

      expected = <<~OUT
        Out: 15
        Out: 10
      OUT
      assert_equal expected, stdout
    ensure
      File.delete('/tmp/explicit_return_test.wl') if File.exist?('/tmp/explicit_return_test.wl')
      File.delete('out.exe') if File.exist?('out.exe')
      File.delete('out.ll') if File.exist?('out.ll')
    end
  end

  # Test that functions without returns fail with proper error
  def test_no_return_statements_error
    test_code = <<~Walrus
      func noreturn() {
          var x = 5;
          print x;
      }

      print noreturn();
    Walrus

    File.write('/tmp/no_return_test.wl', test_code)

    begin
      stdout, stderr, status = Open3.capture3("#{COMPILER} compile /tmp/no_return_test.wl")
      output = stdout + stderr

      refute status.success?, "Expected compilation to fail when function has no returns"

      # Assert error mentions no return statements
      assert_match(/no.*return/i, output,
                   "Expected error to mention missing return statements")

      assert_match(/noreturn/i, output,
                   "Expected error to mention function name")

      # Assert message suggests adding return type or return statement
      assert_match(/return/i, output, "Expected error to mention return")
    ensure
      File.delete('/tmp/no_return_test.wl') if File.exist?('/tmp/no_return_test.wl')
      File.delete('out.exe') if File.exist?('out.exe')
      File.delete('out.ll') if File.exist?('out.ll')
    end
  end

  # Test inferred return types work with control flow
  def test_inferred_with_branches
    test_code = <<~Walrus
      func abs(x int) {
          if x < 0 {
              return -x;
          } else {
              return x;
          }
      }

      func sign(x int) {
          if x < 0 {
              return -1;
          }
          if x > 0 {
              return 1;
          }
          return 0;
      }

      print abs(-42);
      print abs(42);
      print sign(-5);
      print sign(5);
      print sign(0);
    Walrus

    File.write('/tmp/branches_test.wl', test_code)

    begin
      stdout, stderr, status = Open3.capture3("#{COMPILER} compile /tmp/branches_test.wl -o out.exe")
      assert status.success?, "Inferred types in branches should compile: #{stderr}"

      stdout, stderr, status = Open3.capture3('./out.exe')
      assert status.success?, "Execution should succeed: #{stderr}"

      expected = <<~OUT
        Out: 42
        Out: 42
        Out: -1
        Out: 1
        Out: 0
      OUT
      assert_equal expected, stdout
    ensure
      File.delete('/tmp/branches_test.wl') if File.exist?('/tmp/branches_test.wl')
      File.delete('out.exe') if File.exist?('out.exe')
      File.delete('out.ll') if File.exist?('out.ll')
    end
  end

  # Test that recursive functions with explicit types still work
  def test_recursive_functions_with_explicit_types
    # fib.wl already has explicit types, so we test it works
    output = compile_and_run('fib.wl')

    # Just verify it runs without errors and produces expected fibonacci sequence
    lines = output.lines
    assert_equal 30, lines.length, "Expected 30 fibonacci numbers"
    assert_match(/Out: 1/, lines[0], "First fibonacci should be 1")
    assert_match(/Out: 1/, lines[1], "Second fibonacci should be 1")
    assert_match(/Out: 2/, lines[2], "Third fibonacci should be 2")
  end
end
