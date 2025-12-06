require_relative "../test_context"

class TestFloatSupport < Minitest::Test
  def test_float_literals_get_correct_llvm_type
    source = <<~Walrus
      var x = 2.5;
      print x;
    Walrus

    llvm_ir = compile_to_llvm(source)

    # Should declare double global, not i32
    assert_match(/@x = global double 0/, llvm_ir, "Global should be double type")

    # Should store double value, not i32
    assert_match(/store double 2.5, double\* @x/, llvm_ir, "Store should use double type")

    # Should load double, not i32
    assert_match(/load double, double\* @x/, llvm_ir, "Load should use double type")

    # Should call float print function
    assert_match(/@_print_float/, llvm_ir, "Should call float print function")
  end

  def test_float_arithmetic_uses_fadd_not_add
    source = <<~Walrus
      var x = 1.5;
      var y = 2.5;
      var z = x + y;
      print z;
    Walrus

    llvm_ir = compile_to_llvm(source)

    # Should use fadd for float addition
    assert_match(/fadd double/, llvm_ir, "Float addition should use fadd")
    refute_match(/add i32/, llvm_ir, "Should not use integer add for floats")
  end

  def test_float_negation_uses_fneg
    source = <<~Walrus
      var x = 3.14;
      var y = -x;
      print y;
    Walrus

    llvm_ir = compile_to_llvm(source)

    # Should use fneg for float negation
    assert_match(/fneg double/, llvm_ir, "Float negation should use fneg")
  end

  def test_integer_negation_uses_sub
    source = <<~Walrus
      var x = 42;
      var y = -x;
      print y;
    Walrus

    llvm_ir = compile_to_llvm(source)

    # Should use sub for integer negation
    assert_match(/sub i32 0,/, llvm_ir, "Integer negation should use sub from zero")
    refute_match(/fneg/, llvm_ir, "Should not use fneg for integers")
  end

  def test_float_comparison_uses_fcmp
    source = <<~Walrus
      var x = 1.5;
      var y = 2.5;
      if x < y {
        print 1;
      }
    Walrus

    llvm_ir = compile_to_llvm(source)

    # Should use fcmp for float comparison
    assert_match(/fcmp olt double/, llvm_ir, "Float comparison should use fcmp")
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
