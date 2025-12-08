require_relative "../test_context"

# Integration tests for WasmGC compilation target
# Tests the full compilation pipeline from source code to WAT output
class TestWasmGCCompilation < Minitest::Test
  def setup
    Walrus.reset_context
    Walrus.context[:filename] = 'test.wl'
    Walrus.context[:warnings] = []
  end

  # Helper to run full WasmGC compilation pipeline
  def compile_to_wasm(source)
    state = source.dup

    # Run all shared passes + WasmGC backend passes
    passes = Walrus::CompilerPipeline::SHARED_PASSES + Walrus::CompilerPipeline::WASMGC_PASSES

    passes.reduce(state) do |state, pass|
      pass.new.run(state)
    end
  end

  # Helper to read fixture file
  def read_fixture(filename)
    File.read(File.join(__dir__, "../fixtures/#{filename}"))
  end

  # Test simple program compilation
  def test_simple_variable_and_print
    source = <<~WALRUS
      var x = 10;
      print x;
    WALRUS

    result = compile_to_wasm(source)

    assert_kind_of String, result
    assert_includes result, '(module'
    assert_includes result, 'global $x'
    assert_includes result, 'i32.const 10'
    assert_includes result, 'global.set $x'
    assert_includes result, 'global.get $x'
    assert_includes result, 'call $_print_int'
  end

  # Test arithmetic operations
  def test_arithmetic_operations
    source = <<~WALRUS
      var a = 10;
      var b = 5;
      print a + b;
      print a - b;
      print a * b;
      print a / b;
    WALRUS

    result = compile_to_wasm(source)

    assert_includes result, 'i32.add'
    assert_includes result, 'i32.sub'
    assert_includes result, 'i32.mul'
    assert_includes result, 'i32.div_s'
  end

  # Test float operations
  def test_float_operations
    source = <<~WALRUS
      var x float = 3.14;
      var y float = 2.0;
      print x + y;
    WALRUS

    result = compile_to_wasm(source)

    assert_includes result, 'f64.const'
    assert_includes result, 'f64.add'
  end

  # Test function with parameters
  def test_function_with_parameters
    source = <<~WALRUS
      func add(a int, b int) int {
        return a + b;
      }
      print add(3, 4);
    WALRUS

    result = compile_to_wasm(source)

    assert_includes result, '(func $add'
    assert_includes result, '(param $a i32)'
    assert_includes result, '(param $b i32)'
    assert_includes result, '(result i32)'
    assert_includes result, 'local.get $a'
    assert_includes result, 'local.get $b'
    assert_includes result, 'call $add'
  end

  # Test comparison operations
  def test_comparison_operations
    source = <<~WALRUS
      var x = 5;
      var y = 10;
      if x < y {
        print 1;
      } else {
        print 0;
      }
    WALRUS

    result = compile_to_wasm(source)

    assert_includes result, 'i32.lt_s'
    assert_includes result, 'if'
    assert_includes result, 'else'
    assert_includes result, 'end'
  end

  # Test while loop
  def test_while_loop
    source = <<~WALRUS
      var i = 0;
      while i < 3 {
        print i;
        i = i + 1;
      }
    WALRUS

    result = compile_to_wasm(source)

    assert_includes result, 'loop'
    assert_includes result, 'br_if'
    assert_includes result, 'br'
  end

  # Test local variables in function
  def test_local_variables
    source = <<~WALRUS
      func test() int {
        var x = 10;
        var y = 20;
        return x + y;
      }
      print test();
    WALRUS

    result = compile_to_wasm(source)

    assert_includes result, '(local $x i32)'
    assert_includes result, '(local $y i32)'
    assert_includes result, 'local.set $x'
    assert_includes result, 'local.set $y'
    assert_includes result, 'local.get $x'
    assert_includes result, 'local.get $y'
  end

  # Test runtime imports are present
  def test_runtime_imports
    source = "print 42;"

    result = compile_to_wasm(source)

    assert_includes result, '(import "runtime" "print_int"'
    assert_includes result, '(import "runtime" "print_float"'
    assert_includes result, '(import "runtime" "print_char"'
    assert_includes result, '(import "runtime" "gets_int"'
  end

  # Test main function is exported
  def test_main_exported
    source = "print 42;"

    result = compile_to_wasm(source)

    assert_includes result, '(func $main (export "main")'
  end

  # Test unary negation
  def test_unary_negation
    source = <<~WALRUS
      var x = 5;
      print -x;
    WALRUS

    result = compile_to_wasm(source)

    # Negation can be implemented as multiplication by -1 or subtraction from 0
    assert(result.include?('i32.const -1') || result.include?('i32.sub'))
  end

  # Test complex expression
  def test_complex_expression
    source = <<~WALRUS
      var x = 10;
      print (x + 5) * 2;
    WALRUS

    result = compile_to_wasm(source)

    assert_includes result, 'global.get $x'
    assert_includes result, 'i32.const 5'
    assert_includes result, 'i32.add'
    assert_includes result, 'i32.const 2'
    assert_includes result, 'i32.mul'
  end

  # Test fixture file compilation (program1.wl)
  def test_program1_fixture
    source = read_fixture('program1.wl')

    result = compile_to_wasm(source)

    assert_kind_of String, result
    assert_includes result, '(module'
    assert_includes result, 'global $x'
  end

  # Test fixture file compilation (operators.wl)
  def test_operators_fixture
    source = read_fixture('operators.wl')

    result = compile_to_wasm(source)

    assert_kind_of String, result
    assert_includes result, '(module'
  end

  # Test fixture file compilation (unary.wl)
  def test_unary_fixture
    source = read_fixture('unary.wl')

    result = compile_to_wasm(source)

    assert_kind_of String, result
    assert_includes result, '(module'
  end
end
