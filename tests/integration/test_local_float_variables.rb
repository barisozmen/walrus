require_relative "../test_context"

# Test that local float variables inside functions work correctly
class TestLocalFloatVariables < Minitest::Test

  def test_local_float_variable_with_inferred_type_allocates_double
    source = <<~Walrus
      func add(a float, b float) float {
        var c = a + b;
        return c;
      }
    Walrus

    llvm = compile_to_llvm(source)

    # Local variable c must allocate double, not i32
    assert_match(/%c = alloca double/, llvm, "Local variable 'c' alloca must be double, not i32")
    refute_match(/%c = alloca i32/, llvm, "Local variable 'c' should NOT be i32")
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
