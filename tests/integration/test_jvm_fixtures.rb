require_relative '../test_context'
require 'tempfile'
require 'fileutils'

class TestJVMFixtures < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, '..', 'fixtures')

  def setup
    @temp_dir = Dir.mktmpdir('walrus_jvm_fixtures')
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def compile_fixture_to_jvm(fixture_name)
    fixture_path = File.join(FIXTURES_DIR, fixture_name)
    skip "Fixture #{fixture_name} not found" unless File.exist?(fixture_path)

    source = File.read(fixture_path)
    output = File.join(@temp_dir, fixture_name.sub('.wl', '.exe'))

    Walrus.reset_context
    Walrus.context[:filename] = fixture_name
    Walrus.context[:warnings] = []

    begin
      pipeline = Walrus::CompilerPipeline.new(ui: create_silent_ui)
      pipeline.compile(
        source: source,
        output: output,
        runtime: nil,
        target: 'jvm'
      )

      class_file = output.sub('.exe', '.class')
      return { class_file: class_file, source: source, success: true }
    rescue => e
      return { error: e, source: source, success: false }
    end
  end

  def run_jvm_class(class_file)
    class_name = File.basename(class_file, '.class')
    class_dir = File.dirname(class_file)

    result = `java -cp #{class_dir} #{class_name} 2>&1`
    exit_code = $?.exitstatus

    { output: result, exit_code: exit_code }
  end

  def create_silent_ui
    require_relative '../../lib/ui/ui'
    require 'stringio'
    Walrus::UI.new(out: StringIO.new, err: StringIO.new)
  end

  # Test simple programs
  def test_program1
    result = compile_fixture_to_jvm('program1.wl')
    assert result[:success], "Should compile successfully"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code], "Should run successfully"
  end

  def test_program2
    result = compile_fixture_to_jvm('program2.wl')
    assert result[:success], "Should compile successfully"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
  end

  # Test factorial (recursive function)
  def test_fact
    result = compile_fixture_to_jvm('fact.wl')
    assert result[:success], "Should compile factorial program"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
    # Factorial of 5 = 120
    assert_match /120/, output[:output], "Should compute factorial correctly"
  end

  # Test fibonacci
  def test_fib
    result = compile_fixture_to_jvm('fib.wl')
    assert result[:success], "Should compile fibonacci program"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
  end

  # Test float operations
  def test_floats
    result = compile_fixture_to_jvm('floats.wl')
    assert result[:success], "Should compile float operations"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
  end

  # Test for loops
  def test_forloop
    result = compile_fixture_to_jvm('forloop.wl')
    assert result[:success], "Should compile for loop"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
  end

  # Test nested for loops
  def test_nested_forloop
    result = compile_fixture_to_jvm('nested_forloop.wl')
    assert result[:success], "Should compile nested for loops"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
  end

  # Test break and continue
  def test_breakcontinue
    result = compile_fixture_to_jvm('breakcontinue.wl')
    assert result[:success], "Should compile break/continue"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
  end

  # Test comparison operators
  def test_relations
    result = compile_fixture_to_jvm('relations.wl')
    assert result[:success], "Should compile comparison operators"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
  end

  # Test all arithmetic operators
  def test_operators
    result = compile_fixture_to_jvm('operators.wl')
    assert result[:success], "Should compile arithmetic operators"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
  end

  # Test unary operators
  def test_unary
    result = compile_fixture_to_jvm('unary.wl')
    assert result[:success], "Should compile unary operators"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
  end

  # Test elsif chains
  def test_elsif_chain
    result = compile_fixture_to_jvm('elsif_chain.wl')
    assert result[:success], "Should compile elsif chain"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
  end

  # Test short-circuit evaluation
  def test_shortcircuit
    result = compile_fixture_to_jvm('shortcircuit.wl')
    assert result[:success], "Should compile short-circuit operators"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
  end

  # Test operator precedence
  def test_precedence
    result = compile_fixture_to_jvm('precedence.wl')
    assert result[:success], "Should compile operator precedence correctly"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
  end

  # Test prime number calculation
  def test_primes
    result = compile_fixture_to_jvm('primes.wl')
    assert result[:success], "Should compile prime number program"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
    # Should print some primes
    assert_match /2/, output[:output]
    assert_match /3/, output[:output]
    assert_match /5/, output[:output]
    assert_match /7/, output[:output]
  end

  # Test expression statements
  def test_exprstatement
    result = compile_fixture_to_jvm('exprstatement.wl')
    assert result[:success], "Should compile expression statements"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
  end

  # Test specifier (explicit type annotations)
  def test_specifier
    result = compile_fixture_to_jvm('specifier.wl')
    assert result[:success], "Should compile type specifiers"

    output = run_jvm_class(result[:class_file])
    assert_equal 0, output[:exit_code]
  end

  # Test that error cases are still detected
  def test_error_type_mismatch_detected
    result = compile_fixture_to_jvm('error_type_mismatch.wl')
    refute result[:success], "Should detect type mismatch error"
    assert result[:error].is_a?(Walrus::CompilerError::TypeError)
  end

  def test_error_unknown_var_detected
    result = compile_fixture_to_jvm('error_unknown_var.wl')
    refute result[:success], "Should detect unknown variable error"
  end

  # Bulk test: Compile all non-error fixtures
  def test_compile_all_valid_fixtures
    valid_fixtures = Dir.glob(File.join(FIXTURES_DIR, '*.wl')).select do |f|
      !File.basename(f).start_with?('error_') &&
      !File.basename(f).include?('gets_') &&  # Skip interactive programs
      !File.basename(f).include?('string_') &&  # Skip string programs (not fully implemented)
      !File.basename(f).include?('game_of_life') &&  # Skip complex programs
      !File.basename(f).include?('mandel') &&
      !File.basename(f).include?('julia')
    end

    compiled = 0
    failed = []

    valid_fixtures.each do |fixture_path|
      fixture_name = File.basename(fixture_path)

      begin
        result = compile_fixture_to_jvm(fixture_name)
        if result[:success]
          compiled += 1
        else
          failed << { name: fixture_name, error: result[:error] }
        end
      rescue => e
        failed << { name: fixture_name, error: e }
      end
    end

    puts "\nJVM Compilation Summary:"
    puts "  Compiled: #{compiled}/#{valid_fixtures.size}"
    puts "  Failed: #{failed.size}"

    if failed.any?
      puts "\nFailed fixtures:"
      failed.each do |f|
        puts "  - #{f[:name]}: #{f[:error].class} - #{f[:error].message[0..100]}"
      end
    end

    # Assert at least 70% success rate
    success_rate = compiled.to_f / valid_fixtures.size
    assert success_rate >= 0.7, "Should compile at least 70% of fixtures (got #{(success_rate * 100).round}%)"
  end
end
