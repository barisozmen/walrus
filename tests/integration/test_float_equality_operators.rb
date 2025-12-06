require_relative "../test_context"

# Integration test: Float equality/inequality must use fcmp in generated LLVM
class TestFloatEqualityOperators < Minitest::Test

  def test_float_equality_comparison_uses_fcmp_oeq
    source = <<~Walrus
      var x = 3.14;
      var y = 3.14;
      if x == y {
        print 1;
      }
    Walrus

    llvm = compile_to_llvm(source)

    # Must use fcmp oeq for float equality
    assert_match(/fcmp oeq double/, llvm, "Float == must use fcmp oeq")

    # Must NOT use icmp eq with doubles
    refute_match(/icmp eq double/, llvm, "Float == must NOT use icmp eq")
  end

  def test_float_inequality_comparison_uses_fcmp_one
    source = <<~Walrus
      var x = 3.14;
      var y = 2.71;
      if x != y {
        print 1;
      }
    Walrus

    llvm = compile_to_llvm(source)

    # Must use fcmp one for float inequality
    assert_match(/fcmp one double/, llvm, "Float != must use fcmp one")

    # Must NOT use icmp ne with doubles
    refute_match(/icmp ne double/, llvm, "Float != must NOT use icmp ne")
  end

  def test_int_equality_still_uses_icmp_eq
    source = <<~Walrus
      var x = 10;
      var y = 10;
      if x == y {
        print 1;
      }
    Walrus

    llvm = compile_to_llvm(source)

    # Integer equality should still use icmp eq
    assert_match(/icmp eq i32/, llvm, "Int == must use icmp eq")
    refute_match(/fcmp/, llvm, "Int == must NOT use fcmp")
  end

  def test_mixed_comparisons_in_same_program
    source = <<~Walrus
      var a = 10;
      var b = 10;
      var x = 3.14;
      var y = 3.14;

      if a == b {
        print 1;
      }

      if x == y {
        print 2;
      }
    Walrus

    llvm = compile_to_llvm(source)

    # Should have both icmp for ints and fcmp for floats
    assert_match(/icmp eq i32/, llvm, "Int comparison must use icmp")
    assert_match(/fcmp oeq double/, llvm, "Float comparison must use fcmp")
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
