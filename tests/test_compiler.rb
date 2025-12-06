#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'open3'

class CompilerTest < Minitest::Test
  TMP_DIR = File.expand_path('../tmp', __dir__)
  COMPILER = File.expand_path('../compile.rb', __dir__)

  def setup
    FileUtils.mkdir_p(TMP_DIR)
  end

  def teardown
    FileUtils.rm_rf(TMP_DIR)
  end

  def test_basic_arithmetic
    code = <<~WAB
      print 2 + 3;
      print 4 * 5;
    WAB

    assert_equal "Out: 5\nOut: 20\n", compile_and_run(code)
  end

  def test_variables_and_assignment
    code = <<~WAB
      var x = 10;
      var y = 20;
      print x + y;
      x = 15;
      print x;
    WAB

    assert_equal "Out: 30\nOut: 15\n", compile_and_run(code)
  end

  def test_functions
    code = <<~WAB
      func double(n int) int{
        return n * 2;
      }

      print double(5);
      print double(10);
    WAB

    assert_equal "Out: 10\nOut: 20\n", compile_and_run(code)
  end

  def test_conditionals
    code = <<~WAB
      var x = 5;
      if x < 10 {
        print 1;
      } else {
        print 0;
      }

      if x == 5 {
        print 42;
      } else {
        print 0;
      }
    WAB

    assert_equal "Out: 1\nOut: 42\n", compile_and_run(code)
  end

  def test_loops
    code = <<~WAB
      var i = 0;
      while i < 5 {
        print i;
        i = i + 1;
      }
    WAB

    assert_equal "Out: 0\nOut: 1\nOut: 2\nOut: 3\nOut: 4\n", compile_and_run(code)
  end

  private

  def compile_and_run(code)
    source_file = File.join(TMP_DIR, "test.wab")
    executable = File.join(TMP_DIR, "test.exe")

    File.write(source_file, code)

    # Compile
    compile_cmd = "ruby #{COMPILER} compile #{source_file} -o #{executable}"
    stdout, stderr, status = Open3.capture3(compile_cmd)

    assert status.success?, "Compilation failed:\n#{stderr}\n#{stdout}"

    # Run
    run_cmd = executable
    stdout, stderr, status = Open3.capture3(run_cmd)

    assert status.success?, "Execution failed:\n#{stderr}"
    stdout
  end
end
