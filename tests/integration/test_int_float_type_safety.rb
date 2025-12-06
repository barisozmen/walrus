require_relative "../test_context"

# Test type safety: int and float should not mix
class TestIntFloatTypeSafety < Minitest::Test

  # Mixed-type arithmetic should fail during type checking
  def test_cannot_add_int_and_float
    source = <<~Walrus
      var x = 10;
      var y = 3.14;
      var z = x + y;
    Walrus

    error = assert_raises(CompilerError::TypeError) { compile_to_llvm(source) }
    assert_match(/type mismatch.*int.*float/i, error.message)
  end

  # Cannot assign float to int variable
  def test_cannot_assign_float_to_int_variable
    source = <<~Walrus
      var x int;
      x = 3.14;
    Walrus

    error = assert_raises(CompilerError::TypeError) { compile_to_llvm(source) }
    assert_match(/cannot assign float to.*int/i, error.message)
  end

  # Cannot assign int to float variable
  def test_cannot_assign_int_to_float_variable
    source = <<~Walrus
      var x float;
      x = 42;
    Walrus

    error = assert_raises(CompilerError::TypeError) { compile_to_llvm(source) }
    assert_match(/cannot assign int to.*float/i, error.message)
  end

  # Comparison operations should reject mixed types
  def test_cannot_compare_int_and_float
    source = <<~Walrus
      var x = 10;
      var y = 3.14;
      if x < y {
        print 1;
      }
    Walrus

    error = assert_raises(CompilerError::TypeError) { compile_to_llvm(source) }
    assert_match(/type mismatch.*int.*float/i, error.message)
  end

  # Same-type operations work fine
  def test_int_operations_remain_separate
    source = <<~Walrus
      var a = 10;
      var b = 20;
      var sum = a + b;
      var neg = -a;
      print sum;
      print neg;
    Walrus

    llvm = compile_to_llvm(source)

    # All operations should be integer
    assert_match(/add i32/, llvm)
    assert_match(/sub i32 0,/, llvm)
    # Don't check for 'double' in function declaration preamble, only in actual operations
    refute_match(/fadd|fneg/, llvm, "No float operations")
  end

  def test_float_operations_remain_separate
    source = <<~Walrus
      var a = 10.0;
      var b = 20.0;
      var sum = a + b;
      var neg = -a;
      print sum;
      print neg;
    Walrus

    llvm = compile_to_llvm(source)

    # All operations should be float
    assert_match(/fadd double/, llvm)
    assert_match(/fneg double/, llvm)
    refute_match(/add i32|sub i32 0,/, llvm, "No integer operations")
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
