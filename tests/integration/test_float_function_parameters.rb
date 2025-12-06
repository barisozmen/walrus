require_relative "../test_context"

# Test that float function parameters work end-to-end
class TestFloatFunctionParameters < Minitest::Test

  # This is the core issue: entry block must allocate correct types
  def test_float_function_entry_block_uses_double_alloca
    source = <<~Walrus
      func add(a float, b float) float {
        return a + b;
      }
    Walrus

    llvm = compile_to_llvm(source)

    # Entry block must allocate double, not i32
    assert_match(/%a = alloca double/, llvm, "Parameter 'a' alloca must be double")
    assert_match(/%b = alloca double/, llvm, "Parameter 'b' alloca must be double")

    # Stores must use double
    assert_match(/store double %.arg_a, double\* %a/, llvm, "Store arg_a as double")
    assert_match(/store double %.arg_b, double\* %b/, llvm, "Store arg_b as double")
  end

  # Simpler test: no functions, just global floats (this SHOULD work)
  def test_global_float_variables_work_without_functions
    source = <<~Walrus
      var x = 2.5;
      var y = 3.5;
      var sum = x + y;
      print sum;
    Walrus

    llvm = compile_to_llvm(source)

    # Globals should be double
    assert_match(/@x = global double/, llvm)
    assert_match(/@y = global double/, llvm)
    assert_match(/@sum = global double/, llvm)

    # Operations should be float
    assert_match(/fadd double/, llvm)
    assert_match(/load double, double\*/, llvm)
    assert_match(/store double .+, double\*/, llvm)
  end

  # Test what we CAN compile: integer functions (baseline)
  def test_integer_function_parameters_baseline
    source = <<~Walrus
      func add(a int, b int) int {
        return a + b;
      }

      var result = add(10, 20);
      print result;
    Walrus

    llvm = compile_to_llvm(source)

    # Integer function signature
    assert_match(/define i32 @add\(i32 %.arg_a, i32 %.arg_b\)/, llvm)

    # Entry block allocates i32
    assert_match(/%a = alloca i32/, llvm)
    assert_match(/%b = alloca i32/, llvm)

    # Integer operations
    assert_match(/add i32/, llvm)
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
