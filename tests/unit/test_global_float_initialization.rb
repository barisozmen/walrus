require_relative "../test_context"

# Unit test: Global float variables must initialize with 0.0 not 0
class TestGlobalFloatInitialization < Minitest::Test

  def test_global_float_without_init_generates_zero_dot_zero
    source = <<~Walrus
      var x float;
    Walrus

    llvm = compile_to_llvm(source)

    # Must use 0.0 for double initialization, not 0
    assert_match(/@x = global double 0\.0/, llvm, "Global float must initialize with 0.0")
    refute_match(/@x = global double 0$/, llvm, "Global float must NOT use integer 0")
  end

  def test_global_int_without_init_still_uses_integer_zero
    source = <<~Walrus
      var x int;
    Walrus

    llvm = compile_to_llvm(source)

    # Int should still use integer 0
    assert_match(/@x = global i32 0$/, llvm, "Global int must initialize with integer 0")
  end

  def test_multiple_uninitialized_float_globals
    source = <<~Walrus
      var x float;
      var y float;
      var z float;
    Walrus

    llvm = compile_to_llvm(source)

    # All float globals must use 0.0
    assert_match(/@x = global double 0\.0/, llvm, "Variable x must use 0.0")
    assert_match(/@y = global double 0\.0/, llvm, "Variable y must use 0.0")
    assert_match(/@z = global double 0\.0/, llvm, "Variable z must use 0.0")

    # Count - should have exactly 3 occurrences
    double_zero_count = llvm.scan(/global double 0\.0/).length
    assert_equal 3, double_zero_count, "Should have 3 float globals with 0.0"
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
