require_relative "../test_context"

# Integration test: function calls must use correct argument and return types
class TestFunctionCallTypes < Minitest::Test

  def test_float_function_call_uses_double_types
    source = <<~Walrus
      func add(a float, b float) float {
        return a + b;
      }

      var x = 2.5;
      var y = 3.5;
      var result = add(x, y);
      print result;
    Walrus

    llvm = compile_to_llvm(source)

    # Function signature must use double
    assert_match(/define double @add\(double %.arg_a, double %.arg_b\)/, llvm,
                 "Function signature must use double for float params and return")

    # Function call must pass double arguments and expect double return
    assert_match(/call double \(double, double\) @add\(double .+, double .+\)/, llvm,
                 "Function call must use double types for arguments and return")

    # Must NOT use i32 types in function call
    refute_match(/call i32 .* @add\(i32/, llvm,
                 "Function call must NOT use i32 types")
  end

  def test_int_function_call_uses_i32_types
    source = <<~Walrus
      func add(a int, b int) int {
        return a + b;
      }

      var x = 2;
      var y = 3;
      var result = add(x, y);
      print result;
    Walrus

    llvm = compile_to_llvm(source)

    # Function signature must use i32
    assert_match(/define i32 @add\(i32 %.arg_a, i32 %.arg_b\)/, llvm,
                 "Function signature must use i32 for int params and return")

    # Function call must pass i32 arguments and expect i32 return
    assert_match(/call i32 \(i32, i32\) @add\(i32 .+, i32 .+\)/, llvm,
                 "Function call must use i32 types for arguments and return")

    # Must NOT use double types in function call
    refute_match(/call double .* @add\(double/, llvm,
                 "Function call must NOT use double types")
  end

  def test_function_call_with_literal_float_arguments
    source = <<~Walrus
      func add(a float, b float) float {
        return a + b;
      }

      var result = add(2.5, 3.5);
      print result;
    Walrus

    llvm = compile_to_llvm(source)

    # Function call must use double for literal float arguments (args may be reversed)
    assert_match(/call double \(double, double\) @add\(double .+, double .+\)/, llvm,
                 "Function call with float literals must use double type")
  end

  def test_mixed_type_function_calls
    source = <<~Walrus
      func addint(a int, b int) int {
        return a + b;
      }

      func addfloat(a float, b float) float {
        return a + b;
      }

      var x = addint(1, 2);
      var y = addfloat(1.5, 2.5);
      print x;
      print y;
    Walrus

    llvm = compile_to_llvm(source)

    # Both function signatures should be correct
    assert_match(/define i32 @addint\(i32 %.arg_a, i32 %.arg_b\)/, llvm,
                 "Int function signature must use i32")
    assert_match(/define double @addfloat\(double %.arg_a, double %.arg_b\)/, llvm,
                 "Float function signature must use double")

    # Both function calls should use correct types
    assert_match(/call i32 \(i32, i32\) @addint/, llvm,
                 "Int function call must use i32 types")
    assert_match(/call double \(double, double\) @addfloat/, llvm,
                 "Float function call must use double types")
  end

  def test_function_call_result_stored_with_correct_type
    source = <<~Walrus
      func getfloat() float {
        return 3.14;
      }

      func getint() int {
        return 42;
      }

      var f = getfloat();
      var i = getint();
      print f;
      print i;
    Walrus

    llvm = compile_to_llvm(source)

    # Call results should have correct types
    assert_match(/%.+ = call double \(\) @getfloat\(\)/, llvm,
                 "Float function call should return double")
    assert_match(/%.+ = call i32 \(\) @getint\(\)/, llvm,
                 "Int function call should return i32")

    # Print statements should dispatch correctly based on stored variable types
    assert_match(/call i32 \(double\) @_print_float\(double/, llvm,
                 "Float variable should print via @_print_float")
    assert_match(/call i32 \(i32\) @_print_int\(i32/, llvm,
                 "Int variable should print via @_print_int")
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
