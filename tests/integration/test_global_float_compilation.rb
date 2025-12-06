require_relative "../test_context"

# Integration test: Global float variables must compile and link correctly
class TestGlobalFloatCompilation < Minitest::Test

  def test_uninitialized_global_float_compiles_to_valid_llvm
    source = <<~Walrus
      var pi float;
      var e float;
      print pi;
      print e;
    Walrus

    llvm = compile_to_llvm(source)

    # LLVM should be valid - doubles initialized with 0.0
    assert_match(/@pi = global double 0\.0/, llvm, "pi must use 0.0")
    assert_match(/@e = global double 0\.0/, llvm, "e must use 0.0")

    # This LLVM should be valid for clang (would fail with integer 0)
    refute_match(/global double 0$/, llvm, "No float global should use integer 0")
  end

  def test_mixed_type_globals_use_correct_initializers
    source = <<~Walrus
      var count int;
      var temperature float;
      var done int;
      var ratio float;
    Walrus

    llvm = compile_to_llvm(source)

    # Ints use integer 0
    assert_match(/@count = global i32 0$/, llvm, "Int global uses integer 0")
    assert_match(/@done = global i32 0$/, llvm, "Int global uses integer 0")

    # Floats use 0.0
    assert_match(/@temperature = global double 0\.0/, llvm, "Float global uses 0.0")
    assert_match(/@ratio = global double 0\.0/, llvm, "Float global uses 0.0")
  end

  def test_float_function_result_stored_in_global_compiles
    source = <<~Walrus
      func getvalue() float {
        return 3.14;
      }

      var result float;
      result = getvalue();
      print result;
    Walrus

    llvm = compile_to_llvm(source)

    # Global should initialize with 0.0 for proper LLVM
    assert_match(/@result = global double 0\.0/, llvm,
                 "Global float must use 0.0 for valid LLVM")
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
