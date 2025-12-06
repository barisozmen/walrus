require_relative "../test_context"

class TestFloatFunctions < Minitest::Test
  def test_float_function_parameters_have_correct_llvm_signature
    source = <<~Walrus
      func add(a float, b float) float {
        return a + b;
      }

      var result = add(1.5, 2.5);
      print result;
    Walrus

    llvm_ir = compile_to_llvm(source)

    # Function should have double parameters and return type
    assert_match(/define double @add\(double %.arg_a, double %.arg_b\)/, llvm_ir,
                 "Function signature should use double for float parameters and return")

    # Entry block should allocate double, not i32
    assert_match(/%a = alloca double/, llvm_ir, "Parameter allocation should be double")
    assert_match(/%b = alloca double/, llvm_ir, "Parameter allocation should be double")

    # Stores should be double
    assert_match(/store double %.arg_a, double\* %a/, llvm_ir, "Parameter store should be double")
  end

  def test_mixed_parameter_types
    source = <<~Walrus
      func convert(i int, f float) float {
        return f;
      }

      print convert(10, 3.14);
    Walrus

    llvm_ir = compile_to_llvm(source)

    # Function should have mixed parameter types
    assert_match(/define double @convert\(i32 %.arg_i, double %.arg_f\)/, llvm_ir,
                 "Mixed parameter types should work")
  end

  def test_integer_functions_still_work
    source = <<~Walrus
      func add(a int, b int) int {
        return a + b;
      }

      var result = add(10, 20);
      print result;
    Walrus

    llvm_ir = compile_to_llvm(source)

    # Integer functions should still use i32
    assert_match(/define i32 @add\(i32 %.arg_a, i32 %.arg_b\)/, llvm_ir,
                 "Integer function signature should use i32")
    assert_match(/%a = alloca i32/, llvm_ir, "Integer parameter allocation")
    assert_match(/store i32 %.arg_a, i32\* %a/, llvm_ir, "Integer parameter store")
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
