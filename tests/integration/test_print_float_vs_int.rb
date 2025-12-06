require_relative "../test_context"

# Integration test: print must dispatch to correct runtime function based on type
class TestPrintFloatVsInt < Minitest::Test

  def test_print_float_variable_calls_print_float_not_print_int
    source = <<~Walrus
      var x = 3.14;
      print x;
    Walrus

    llvm = compile_to_llvm(source)

    # Must call @_print_float with double argument
    assert_match(/@_print_float/, llvm, "Float print must call @_print_float")
    assert_match(/call i32 \(double\) @_print_float\(double/, llvm, "Must call @_print_float with double argument")

    # Must NOT call @_print_int
    refute_match(/call i32 \(i32\) @_print_int/, llvm, "Float print must NOT call @_print_int")
  end

  def test_print_int_variable_calls_print_int_not_print_float
    source = <<~Walrus
      var x = 42;
      print x;
    Walrus

    llvm = compile_to_llvm(source)

    # Must call @_print_int with i32 argument
    assert_match(/@_print_int/, llvm, "Int print must call @_print_int")
    assert_match(/call i32 \(i32\) @_print_int\(i32/, llvm, "Must call @_print_int with i32 argument")

    # Must NOT call @_print_float
    refute_match(/call i32 \(double\) @_print_float/, llvm, "Int print must NOT call @_print_float")
  end

  def test_print_float_expression_calls_print_float
    source = <<~Walrus
      var x = 2.5;
      var y = 3.5;
      print x + y;
    Walrus

    llvm = compile_to_llvm(source)

    # Must call @_print_float for float expression result
    assert_match(/call i32 \(double\) @_print_float\(double/, llvm, "Float expression print must call @_print_float")
    refute_match(/call i32 \(i32\) @_print_int/, llvm, "Float expression print must NOT call @_print_int")
  end

  def test_print_int_expression_calls_print_int
    source = <<~Walrus
      var x = 2;
      var y = 3;
      print x + y;
    Walrus

    llvm = compile_to_llvm(source)

    # Must call @_print_int for int expression result
    assert_match(/call i32 \(i32\) @_print_int\(i32/, llvm, "Int expression print must call @_print_int")
    refute_match(/call i32 \(double\) @_print_float/, llvm, "Int expression print must NOT call @_print_float")
  end

  def test_multiple_prints_with_different_types
    source = <<~Walrus
      var a = 10;
      var b = 3.14;
      print a;
      print b;
    Walrus

    llvm = compile_to_llvm(source)

    # Must have both print functions
    assert_match(/call i32 \(i32\) @_print_int\(i32/, llvm, "Must call @_print_int for integer")
    assert_match(/call i32 \(double\) @_print_float\(double/, llvm, "Must call @_print_float for float")

    # Count occurrences - should be exactly one of each
    int_calls = llvm.scan(/call i32 \(i32\) @_print_int\(i32/).length
    float_calls = llvm.scan(/call i32 \(double\) @_print_float\(double/).length

    assert_equal 1, int_calls, "Should have exactly one @_print_int call"
    assert_equal 1, float_calls, "Should have exactly one @_print_float call"
  end

  private

  def compile_to_llvm(source)
    [
      Walrus::Tokenizer, Walrus::Parser, Walrus::FoldConstants,
      Walrus::DeinitializeVariableDeclarations, Walrus::ResolveVariableScopes,
      Walrus::InferAndCheckTypes, Walrus::GatherTopLevelStatementsIntoMain,
      Walrus::EnsureAllFunctionsHaveExplicitReturns,
      Walrus::LowerExpressionsToInstructions, Walrus::LowerStatementsToInstructions,
      Walrus::MergeStatementsIntoBasicBlocks, Walrus::FlattenControlFlow,
      Walrus::GenerateLLVMCode, Walrus::AddLlvmEntryBlocks, Walrus::FormatLlvm
    ].reduce(source) { |result, pass| pass.new.run(result) }
  end
end
