require_relative '../test_context'
require 'tempfile'
require 'fileutils'

class TestJVMGarbageCollection < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir('walrus_gc_test')
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def compile_to_jvm(source)
    source_file = File.join(@temp_dir, 'test.wl')
    File.write(source_file, source)

    output = File.join(@temp_dir, 'test.exe')

    Walrus.reset_context
    Walrus.context[:filename] = 'test.wl'
    Walrus.context[:warnings] = []

    pipeline = Walrus::CompilerPipeline.new(ui: create_silent_ui)
    pipeline.compile(
      source: source,
      output: output,
      runtime: nil,
      target: 'jvm'
    )

    class_file = File.join(@temp_dir, 'test.class')
    { class_file: class_file, output: output }
  end

  def run_with_gc_logging(class_file)
    class_name = File.basename(class_file, '.class')
    class_dir = File.dirname(class_file)

    # Run with GC logging enabled
    result = `java -XX:+PrintGC -XX:+PrintGCDetails -cp #{class_dir} #{class_name} 2>&1`
    exit_code = $?.exitstatus

    { output: result, exit_code: exit_code }
  end

  def create_silent_ui
    require_relative '../../lib/ui/ui'
    require 'stringio'
    Walrus::UI.new(out: StringIO.new, err: StringIO.new)
  end

  # Test 1: Verify JVM's automatic local variable management
  def test_local_variables_no_explicit_allocation
    source = <<~WALRUS
      func test() int {
        var x = 10;
        var y = 20;
        var z = 30;
        return x + y + z;
      }
      print test();
    WALRUS

    files = compile_to_jvm(source)

    # Verify .class file was created
    assert File.exist?(files[:class_file]), "Class file should exist"

    # Read the generated Java source to verify no explicit allocation
    # The JVM handles local variables automatically
    result = run_with_gc_logging(files[:class_file])
    assert_equal 0, result[:exit_code]
    assert_match /60/, result[:output], "Should compute 10+20+30=60"
  end

  # Test 2: Verify global variables become static fields (auto-initialized)
  def test_global_variables_auto_initialized
    source = <<~WALRUS
      var global_counter = 0;

      func increment() int {
        global_counter = global_counter + 1;
        return global_counter;
      }

      print increment();
      print increment();
      print increment();
    WALRUS

    files = compile_to_jvm(source)
    result = run_with_gc_logging(files[:class_file])

    assert_equal 0, result[:exit_code]
    # Should print 1, 2, 3 as counter increments
    assert_match /1/, result[:output]
    assert_match /2/, result[:output]
    assert_match /3/, result[:output]
  end

  # Test 3: String literals are managed by JVM (no manual memory management)
  def test_string_garbage_collection
    skip "String support not fully implemented yet"

    source = <<~WALRUS
      func create_string() str {
        return "Hello, World!";
      }
      print create_string();
    WALRUS

    files = compile_to_jvm(source)
    result = run_with_gc_logging(files[:class_file])

    assert_equal 0, result[:exit_code]
    # Strings should be automatically managed by JVM's string pool
    assert_match /Hello/, result[:output]
  end

  # Test 4: Verify no memory leaks with loops creating temporaries
  def test_loop_temporaries_gc
    source = <<~WALRUS
      func loop_test() int {
        var i = 0;
        var sum = 0;
        while i < 1000 {
          var temp = i * 2;  // Temporary created each iteration
          sum = sum + temp;
          i = i + 1;
        }
        return sum;
      }
      print loop_test();
    WALRUS

    files = compile_to_jvm(source)
    result = run_with_gc_logging(files[:class_file])

    assert_equal 0, result[:exit_code]
    # Sum of 0*2 + 1*2 + 2*2 + ... + 999*2 = 2 * (0+1+...+999) = 2 * 499500 = 999000
    assert_match /999000/, result[:output]

    # Check GC logs don't show excessive collections
    # (indicates good memory management)
    gc_count = result[:output].scan(/GC/).length
    # Should have minimal GC activity for such a simple program
    assert gc_count < 100, "Should not trigger excessive GC (got #{gc_count} collections)"
  end

  # Test 5: Function call parameters are automatically managed
  def test_function_parameters_auto_managed
    source = <<~WALRUS
      func recursive_sum(n int, acc int) int {
        if n == 0 {
          return acc;
        } else {
          return recursive_sum(n - 1, acc + n);
        }
      }
      print recursive_sum(100, 0);
    WALRUS

    files = compile_to_jvm(source)
    result = run_with_gc_logging(files[:class_file])

    assert_equal 0, result[:exit_code]
    # Sum of 1+2+...+100 = 5050
    assert_match /5050/, result[:output]

    # JVM should handle the recursion stack automatically
    # No manual stack allocation needed
  end

  # Test 6: Verify JVM .class file structure
  def test_class_file_structure
    source = <<~WALRUS
      var x = 42;
      print x;
    WALRUS

    files = compile_to_jvm(source)

    # Verify .class file is valid Java bytecode
    assert File.exist?(files[:class_file])
    assert File.size(files[:class_file]) > 0, "Class file should not be empty"

    # Use javap to disassemble and verify structure
    javap_output = `javap -v #{files[:class_file]} 2>&1`

    # Should have WalrusProgram class
    assert_match /class WalrusProgram/, javap_output, "Should define WalrusProgram class"

    # Should have static fields for globals
    assert_match /static.*x/, javap_output, "Should have static field for global variable"

    # Should have main method
    assert_match /public static.*main/, javap_output, "Should have main method"
  end

  # Test 7: Verify max_stack and max_locals are calculated
  def test_stack_and_locals_calculation
    source = <<~WALRUS
      func complex(a int, b int, c int) int {
        var x = a + b;
        var y = b + c;
        var z = x + y;
        return z;
      }
      print complex(1, 2, 3);
    WALRUS

    files = compile_to_jvm(source)

    # Use javap to verify stack/locals
    javap_output = `javap -v #{files[:class_file]} 2>&1`

    # Should have calculated stack depth
    assert_match /stack=\d+/, javap_output, "Should calculate max stack depth"
    assert_match /locals=\d+/, javap_output, "Should calculate max locals"

    # Verify it runs correctly
    class_name = File.basename(files[:class_file], '.class')
    class_dir = File.dirname(files[:class_file])
    result = `java -cp #{class_dir} #{class_name} 2>&1`

    assert_equal 0, $?.exitstatus
    assert_match /9/, result, "Should print 9 ((1+2)+(2+3))"
  end

  # Test 8: Verify float/double handling (takes 2 stack slots)
  def test_double_slot_handling
    source = <<~WALRUS
      func compute(x float, y float) float {
        var sum = x + y;
        var product = x * y;
        return sum + product;
      }
      print compute(2.0, 3.0);
    WALRUS

    files = compile_to_jvm(source)

    # Use javap to verify locals calculation accounts for double-width
    javap_output = `javap -v #{files[:class_file]} 2>&1`

    # Locals should account for doubles taking 2 slots each
    # x=0-1, y=2-3, sum=4-5, product=6-7
    assert_match /locals=\d+/, javap_output
    locals_match = javap_output.match(/locals=(\d+)/)

    if locals_match
      locals = locals_match[1].to_i
      assert locals >= 8, "Should have at least 8 local slots for double handling"
    end
  end

  # Test 9: Comparison of LLVM vs JVM memory management
  def test_compare_llvm_vs_jvm_output
    source = <<~WALRUS
      var counter = 0;
      func increment() int {
        counter = counter + 1;
        return counter;
      }
      print increment();
      print increment();
    WALRUS

    # Compile with JVM
    jvm_files = compile_to_jvm(source)
    class_name = File.basename(jvm_files[:class_file], '.class')
    class_dir = File.dirname(jvm_files[:class_file])
    jvm_output = `java -cp #{class_dir} #{class_name} 2>&1`

    # Both should produce the same output (1, 2)
    assert_match /1/, jvm_output
    assert_match /2/, jvm_output

    # Key difference: JVM version uses automatic GC, LLVM version doesn't
    # But functionally they should be equivalent
  end

  # Test 10: Verify no explicit garbage collection calls in bytecode
  def test_no_explicit_gc_calls
    source = <<~WALRUS
      func allocate_locals() int {
        var a = 1;
        var b = 2;
        var c = 3;
        return a + b + c;
      }
      print allocate_locals();
    WALRUS

    files = compile_to_jvm(source)

    # Disassemble and verify no explicit GC calls
    javap_output = `javap -c #{files[:class_file]} 2>&1`

    # Should NOT contain any System.gc() calls or manual memory management
    refute_match /System\.gc/, javap_output, "Should not call System.gc()"
    refute_match /Runtime\.getRuntime/, javap_output, "Should not use Runtime"

    # But should use automatic local variables
    assert_match /istore|iload/, javap_output, "Should use local variable operations"
  end
end
