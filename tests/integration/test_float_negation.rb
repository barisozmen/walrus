require_relative "../test_context"

class TestFloatNegation < Minitest::Test
  def test_float_negation_generates_fneg_instruction
    source = <<~Walrus
      var x = 3.14;
      var y = -x;
      print y;
    Walrus

    llvm_ir = compile_to_llvm(source)

    # Critical: float negation must use fneg, not sub
    assert_match(/fneg double/, llvm_ir, "Float negation should use LLVM fneg instruction")
    refute_match(/sub.*0,.*double/, llvm_ir, "Float negation should not use sub from zero")
  end

  def test_integer_negation_still_uses_sub
    source = <<~Walrus
      var x = 42;
      var y = -x;
      print y;
    Walrus

    llvm_ir = compile_to_llvm(source)

    # Integer negation should still work as before
    assert_match(/sub i32 0,/, llvm_ir, "Integer negation should use sub from zero")
    refute_match(/fneg/, llvm_ir, "Integer negation should not use fneg")
  end

  def test_mixed_int_and_float_negation
    source = <<~Walrus
      var a = 10;
      var b = 2.5;
      var c = -a;
      var d = -b;
      print c;
      print d;
    Walrus

    llvm_ir = compile_to_llvm(source)

    # Both types should coexist correctly
    assert_match(/sub i32 0,/, llvm_ir, "Integer negation present")
    assert_match(/fneg double/, llvm_ir, "Float negation present")

    # Verify globals have correct types
    assert_match(/@a = global i32/, llvm_ir, "Integer global")
    assert_match(/@b = global double/, llvm_ir, "Float global")
  end

  private

  def compile_to_llvm(source)
    pipeline = [
      Walrus::Tokenizer,
      Walrus::Parser,
      Walrus::FoldConstants,
      Walrus::DeinitializeVariableDeclarations,
      Walrus::ResolveVariableScopes,
      Walrus::InferAndCheckTypes,
      Walrus::GatherTopLevelStatementsIntoMain,
      Walrus::EnsureAllFunctionsHaveExplicitReturns,
      Walrus::LowerExpressionsToInstructions,
      Walrus::LowerStatementsToInstructions,
      Walrus::MergeStatementsIntoBasicBlocks,
      Walrus::FlattenControlFlow,
      Walrus::GenerateLLVMCode,
      Walrus::AddLlvmEntryBlocks,
      Walrus::FormatLlvm
    ]

    pipeline.reduce(source) { |result, pass| pass.new.run(result) }
  end
end
