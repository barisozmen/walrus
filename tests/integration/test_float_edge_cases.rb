require_relative "../test_context"

# Test the tricky parts: type propagation through complex expressions
class TestFloatEdgeCases < Minitest::Test

  # Division changes operator: sdiv for int, fdiv for float
  def test_division_operator_selection
    int_div = compile_to_llvm("var x = 10; var y = 3; var z = x / y; print z;")
    float_div = compile_to_llvm("var x = 10.0; var y = 3.0; var z = x / y; print z;")

    assert_match(/sdiv i32/, int_div, "Integer division must use sdiv")
    assert_match(/fdiv double/, float_div, "Float division must use fdiv")
  end

  # Type must flow through nested expressions with variables (avoid constant folding)
  def test_nested_float_expressions_preserve_type
    source = <<~Walrus
      var a = 2.5;
      var b = 3.5;
      var result = -(a + b);
      print result;
    Walrus
    llvm = compile_to_llvm(source)

    assert_match(/fadd double/, llvm, "Inner addition must be float")
    assert_match(/fneg double/, llvm, "Outer negation must be float")
    refute_match(/add i32|sub i32 0,/, llvm, "No integer operations")
  end

  # Uninitialized variables must track float type from first assignment
  def test_uninitialized_float_variable_type_inference
    source = <<~Walrus
      var x float;
      x = 3.14;
      var y = -x;
      print y;
    Walrus
    llvm = compile_to_llvm(source)

    assert_match(/@x = global double/, llvm, "Explicit float type on global")
    assert_match(/fneg double/, llvm, "Type preserved through load/negate")
  end

  # Multiple assignments must maintain type consistency
  def test_float_variable_reassignment_maintains_type
    source = <<~Walrus
      var sum = 0.0;
      sum = sum + 1.5;
      sum = sum + 2.5;
      print sum;
    Walrus
    llvm = compile_to_llvm(source)

    # All operations must be float
    assert_match(/@sum = global double/, llvm)
    matches = llvm.scan(/fadd double/).length
    assert_equal 2, matches, "Two float additions"
    refute_match(/add i32/, llvm, "No integer operations")
  end

  # Print must dispatch to correct function based on type
  def test_print_dispatches_to_correct_runtime_function
    int_print = compile_to_llvm("var x = 42; print x;")
    float_print = compile_to_llvm("var x = 42.0; print x;")

    assert_match(/@_print_int/, int_print, "Integer print")
    assert_match(/@_print_float/, float_print, "Float print")
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
