require_relative '../test_context'
require 'tempfile'
require 'fileutils'

class TestJVMCompilation < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir('walrus_jvm_test')
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def compile_and_run_jvm(source)
    # Write source to temp file
    source_file = File.join(@temp_dir, 'test.wl')
    File.write(source_file, source)

    # Compile to JVM
    output = File.join(@temp_dir, 'test.exe')

    Walrus.reset_context
    Walrus.context[:filename] = 'test.wl'
    Walrus.context[:warnings] = []

    pipeline = Walrus::CompilerPipeline.new(ui: create_silent_ui)
    begin
      pipeline.compile(
        source: source,
        output: output,
        runtime: nil,  # Not needed for JVM
        target: 'jvm'
      )
    rescue => e
      flunk "Compilation failed: #{e.message}\n#{e.backtrace.join("\n")}"
    end

    # Verify .class file was created
    class_file = File.join(@temp_dir, 'test.class')
    assert File.exist?(class_file), ".class file should be created"

    # Run the program
    class_name = File.basename(class_file, '.class')
    result = `java -cp #{@temp_dir} #{class_name} 2>&1`
    exit_code = $?.exitstatus

    { output: result, exit_code: exit_code }
  end

  def create_silent_ui
    require_relative '../../lib/ui/ui'
    Walrus::UI.new(verbose: false)
  end

  # Test 1: Simple arithmetic
  def test_simple_arithmetic
    source = <<~WALRUS
      var x = 10 + 20;
      print x;
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code], "Program should exit successfully"
    assert_match /30/, result[:output], "Should print 30"
  end

  # Test 2: Multiple operations
  def test_multiple_operations
    source = <<~WALRUS
      var a = 5 + 3;
      var b = a * 2;
      print b;
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code]
    assert_match /16/, result[:output], "Should print 16"
  end

  # Test 3: Function call
  def test_function_call
    source = <<~WALRUS
      func add(x int, y int) int {
        return x + y;
      }
      var result = add(10, 20);
      print result;
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code]
    assert_match /30/, result[:output], "Should print 30"
  end

  # Test 4: Nested function calls
  def test_nested_function_calls
    source = <<~WALRUS
      func add(x int, y int) int {
        return x + y;
      }
      func double(x int) int {
        return x * 2;
      }
      var result = double(add(5, 3));
      print result;
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code]
    assert_match /16/, result[:output], "Should print 16 (double of 8)"
  end

  # Test 5: Float arithmetic
  def test_float_arithmetic
    source = <<~WALRUS
      var x float = 3.14;
      var y float = 2.0;
      var result = x * y;
      print result;
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code]
    assert_match /6\.28/, result[:output], "Should print 6.28"
  end

  # Test 6: Conditional (if statement)
  def test_conditional
    source = <<~WALRUS
      var x = 10;
      var y = 20;
      if x < y {
        print 1;
      } else {
        print 0;
      }
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code]
    assert_match /1/, result[:output], "Should print 1 (true)"
  end

  # Test 7: While loop
  def test_while_loop
    source = <<~WALRUS
      var i = 0;
      var sum = 0;
      while i < 5 {
        sum = sum + i;
        i = i + 1;
      }
      print sum;
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code]
    assert_match /10/, result[:output], "Should print 10 (0+1+2+3+4)"
  end

  # Test 8: Comparison operations
  def test_comparisons
    source = <<~WALRUS
      var a = 5;
      var b = 10;
      if a < b {
        print 1;
      }
      if a > b {
        print 0;
      } else {
        print 2;
      }
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code]
    # Should print 1 (a < b is true), then 2 (else branch)
    assert_match /1/, result[:output]
    assert_match /2/, result[:output]
  end

  # Test 9: Subtraction and negation
  def test_subtraction_and_negation
    source = <<~WALRUS
      var x = 20 - 5;
      print x;
      var y = -x;
      print y;
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code]
    assert_match /15/, result[:output], "Should print 15"
    assert_match /-15/, result[:output], "Should print -15"
  end

  # Test 10: Multiple prints
  def test_multiple_prints
    source = <<~WALRUS
      print 1;
      print 2;
      print 3;
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code]
    assert_match /1/, result[:output]
    assert_match /2/, result[:output]
    assert_match /3/, result[:output]
  end

  # Test 11: Division
  def test_division
    source = <<~WALRUS
      var x = 20 / 4;
      print x;
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code]
    assert_match /5/, result[:output], "Should print 5"
  end

  # Test 12: Function with multiple parameters
  def test_function_multiple_params
    source = <<~WALRUS
      func sum3(a int, b int, c int) int {
        return a + b + c;
      }
      print sum3(10, 20, 30);
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code]
    assert_match /60/, result[:output], "Should print 60"
  end

  # Test 13: Equality comparison
  def test_equality
    source = <<~WALRUS
      var x = 10;
      var y = 10;
      if x == y {
        print 1;
      } else {
        print 0;
      }
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code]
    assert_match /1/, result[:output], "Should print 1 (equal)"
  end

  # Test 14: Not equal comparison
  def test_not_equal
    source = <<~WALRUS
      var x = 10;
      var y = 20;
      if x != y {
        print 1;
      } else {
        print 0;
      }
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code]
    assert_match /1/, result[:output], "Should print 1 (not equal)"
  end

  # Test 15: Global variable access
  def test_global_variables
    source = <<~WALRUS
      var global_x = 100;

      func get_global() int {
        return global_x;
      }

      print get_global();
    WALRUS

    result = compile_and_run_jvm(source)
    assert_equal 0, result[:exit_code]
    assert_match /100/, result[:output], "Should print 100"
  end
end
