require_relative '../test_context'

# Test the CompilerError hierarchy and error information
# Verifies that errors contain proper location info (line, column) and phase info
# Does NOT test exact error messages (those can change)
class CompilerErrorTest < Minitest::Test

  # Helper to run full compilation pipeline
  def compile_to_llvm(source)
    tokens = Walrus::Tokenizer.new.run(source)
    Walrus::BraceCheck.new.tap { |bc| bc.source_lines = source.lines }.run(tokens)
    ast = Walrus::Parser.new.run(tokens, source: source)
    ast = Walrus::FoldConstants.new.run(ast)
    ast = Walrus::DeinitializeVariableDeclarations.new.run(ast)
    ast = Walrus::ResolveVariableScopes.new.run(ast)
    ast = Walrus::InferAndCheckTypes.new.run(ast)
    ast = Walrus::GatherTopLevelStatementsIntoMain.new.run(ast)
    ast = Walrus::EnsureAllFunctionsHaveExplicitReturns.new.run(ast)
    ast = Walrus::LowerExpressionsToInstructions.new.run(ast)
    ast = Walrus::LowerStatementsToInstructions.new.run(ast)
    ast = Walrus::MergeStatementsIntoBasicBlocks.new.run(ast)
    ast = Walrus::FlattenControlFlow.new.run(ast)
    ast = Walrus::GenerateLLVMCode.new.run(ast)
    ast = Walrus::AddLlvmEntryBlocks.new.run(ast)
    Walrus::FormatLlvm.new.run(ast)
  end

  # ===========================================================================
  # SyntaxError Tests (Tokenizer, Parser, BraceCheck)
  # ===========================================================================

  def test_tokenizer_unexpected_char_has_location
    source = <<~Walrus
      var x = 10;
      var y = @;
    Walrus

    error = assert_raises(CompilerError::SyntaxError) do
      compile_to_llvm(source)
    end

    # Check error contains line and column in new format (at 2:9)
    assert_match(/at 2:\d+/i, error.message, "Should contain line and column")

    # Check error class name
    assert_match(/CompilerError::SyntaxError/i, error.message, "Should show error class")

    # Check location object
    assert_equal :syntactic, error.phase
    assert error.loc, "Should have location object"
    assert_equal 2, error.loc.lineno
  end

  def test_parser_unexpected_token_has_location
    source = <<~Walrus
      var x = 10
      var y = 20;
    Walrus

    error = assert_raises(CompilerError::SyntaxError) do
      compile_to_llvm(source)
    end

    assert_match(/at 2:\d+/i, error.message)
    assert_match(/CompilerError::SyntaxError/i, error.message)
    assert_equal :syntactic, error.phase
  end

  def test_parser_invalid_term_has_location
    source = <<~Walrus
      var x = ;
    Walrus

    error = assert_raises(CompilerError::SyntaxError) do
      compile_to_llvm(source)
    end

    assert_match(/at 1:\d+/i, error.message)
    assert_equal :syntactic, error.phase
    assert error.loc
  end

  def test_bracecheck_unmatched_brace_has_location
    source = <<~Walrus
      var x = 10;
      }
    Walrus

    error = assert_raises(CompilerError::SyntaxError) do
      compile_to_llvm(source)
    end

    assert_match(/at 2:\d+/i, error.message)
    assert_match(/CompilerError::SyntaxError/i, error.message)
    assert_equal :syntactic, error.phase

    # Should show source context
    assert_match(/\^/, error.message, "Should show caret pointer")
  end

  def test_bracecheck_unclosed_brace_has_location
    source = <<~Walrus
      func main() {
        var x = 10;
    Walrus

    error = assert_raises(CompilerError::SyntaxError) do
      compile_to_llvm(source)
    end

    assert_match(/at 1:\d+/i, error.message, "Should point to opening brace line")
    assert_equal :syntactic, error.phase
  end

  # ===========================================================================
  # TypeError Tests (Type Inference & Checking)
  # ===========================================================================

  def test_type_mismatch_has_location
    source = <<~Walrus
      var x = 10;
      var y = 3.14;
      var z = x + y;
    Walrus

    error = assert_raises(CompilerError::TypeError) do
      compile_to_llvm(source)
    end

    assert_match(/at 3:\d+/i, error.message)
    assert_match(/CompilerError::TypeError/i, error.message, "Should show error class")
    assert_equal :semantic, error.phase

    # Should show source context with caret
    assert_match(/\^/, error.message)
    assert_match(/var z = x \+ y;/, error.message, "Should show source line")
  end

  def test_unknown_variable_has_location
    source = <<~Walrus
      var x = 10;
      print y;
    Walrus

    error = assert_raises(CompilerError::TypeError) do
      compile_to_llvm(source)
    end

    assert_match(/at 2:\d+/i, error.message)
    assert_equal :semantic, error.phase
    assert error.loc
    assert_equal 2, error.loc.lineno
  end

  def test_cannot_assign_wrong_type_has_location
    source = <<~Walrus
      var x int;
      x = 3.14;
    Walrus

    error = assert_raises(CompilerError::TypeError) do
      compile_to_llvm(source)
    end

    assert_match(/at 2:\d+/i, error.message)
    assert_match(/CompilerError::TypeError/i, error.message)
    assert_equal :semantic, error.phase

    # Should show caret at assignment
    assert_match(/\^/, error.message)
  end

  def test_unknown_function_has_location
    source = <<~Walrus
      var x = foo();
    Walrus

    error = assert_raises(CompilerError::TypeError) do
      compile_to_llvm(source)
    end

    assert_match(/at 1:\d+/i, error.message)
    assert_equal :semantic, error.phase
    assert error.loc
  end

  def test_wrong_arg_count_has_location
    source = <<~Walrus
      func add(a int, b int) int {
        return a + b;
      }

      var x = add(5);
    Walrus

    error = assert_raises(CompilerError::TypeError) do
      compile_to_llvm(source)
    end

    assert_match(/at 5:\d+/i, error.message)
    assert_equal :semantic, error.phase

    # Should show the problematic call
    assert_match(/add/, error.message)
  end

  # ===========================================================================
  # Error Display Format Tests
  # ===========================================================================

  def test_error_shows_source_context
    source = <<~Walrus
      var x = 10;
      var y = undefinedvar;
    Walrus

    error = assert_raises(CompilerError::TypeError) do
      compile_to_llvm(source)
    end

    # Should show the source line
    assert_match(/var y = undefinedvar;/, error.message)

    # Should show line number prefix
    assert_match(/2 \|/, error.message)

    # Should show caret pointer
    assert_match(/\^/, error.message)
  end

  def test_error_shows_phase_in_header
    source = <<~Walrus
      var x = @;
    Walrus

    error = assert_raises(CompilerError::SyntaxError) do
      compile_to_llvm(source)
    end

    # Error class should be in header
    assert_match(/CompilerError::SyntaxError/i, error.message)
  end

  def test_error_location_format
    source = <<~Walrus
      var x int;
      x = 3.14;
    Walrus

    error = assert_raises(CompilerError::TypeError) do
      compile_to_llvm(source)
    end

    # Location should be formatted as "at <source> at 2:9"
    assert_match(/at <source> at 2:\d+/i, error.message)
  end

  # ===========================================================================
  # Error Object Properties Tests
  # ===========================================================================

  def test_compiler_error_has_phase_attribute
    source = <<~Walrus
      var x = undefined;
    Walrus

    error = assert_raises(CompilerError::TypeError) do
      compile_to_llvm(source)
    end

    assert_respond_to error, :phase
    assert_equal :semantic, error.phase
  end

  def test_compiler_error_has_location_object
    source = <<~Walrus
      var x = 10;
      var y = x + z;
    Walrus

    error = assert_raises(CompilerError::TypeError) do
      compile_to_llvm(source)
    end

    assert_respond_to error, :loc
    assert error.loc, "Error should have location"
    assert_respond_to error.loc, :lineno
    assert_respond_to error.loc, :column
    assert_respond_to error.loc, :source_line

    assert_equal 2, error.loc.lineno
    assert error.loc.column > 0
    assert_match(/var y = x \+ z;/, error.loc.source_line)
  end

  def test_compiler_error_has_severity
    source = <<~Walrus
      var x = @;
    Walrus

    error = assert_raises(CompilerError::SyntaxError) do
      compile_to_llvm(source)
    end

    assert_respond_to error, :severity
    assert_equal :error, error.severity
  end

  # ===========================================================================
  # Helper Method Tests (verify helpers work correctly)
  # ===========================================================================

  def test_helper_method_type_mismatch
    source = <<~Walrus
      var x = 10;
      var y = 3.14;
      print x < y;
    Walrus

    error = assert_raises(CompilerError::TypeError) do
      compile_to_llvm(source)
    end

    # Helper should include both types in message
    assert_match(/int/i, error.message)
    assert_match(/float/i, error.message)

    # Should have proper location
    assert_equal 3, error.loc.lineno
  end

  def test_helper_method_cannot_assign
    source = <<~Walrus
      var x float = 3.14;
      x = 42;
    Walrus

    error = assert_raises(CompilerError::TypeError) do
      compile_to_llvm(source)
    end

    # Helper should mention both types
    assert_match(/int/i, error.message)
    assert_match(/float/i, error.message)

    # Should point to assignment line
    assert_equal 2, error.loc.lineno
  end

  # ===========================================================================
  # Edge Cases
  # ===========================================================================

  def test_error_at_end_of_file
    source = <<~Walrus
      var x = 10
    Walrus

    error = assert_raises(CompilerError::SyntaxError) do
      compile_to_llvm(source)
    end

    # Should handle EOF gracefully
    assert_match(/at 1:\d+/i, error.message)
    assert error.loc
  end

  def test_error_with_multiline_context
    source = <<~Walrus
      func test() int {
        var x int;
        x = 3.14;
        return x;
      }
    Walrus

    error = assert_raises(CompilerError::TypeError) do
      compile_to_llvm(source)
    end

    # Should show the correct line (not first or last)
    assert_equal 3, error.loc.lineno
    assert_match(/x = 3\.14;/, error.message)
  end

  def test_error_in_nested_structure
    source = <<~Walrus
      func outer() int {
        if 1 < 2 {
          var x = undefined;
        }
        return 0;
      }
    Walrus

    error = assert_raises(CompilerError::TypeError) do
      compile_to_llvm(source)
    end

    # Should point to correct nested line
    assert_equal 3, error.loc.lineno
    assert_match(/var x = undefined;/, error.message)
  end
end
