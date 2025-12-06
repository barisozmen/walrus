require_relative "../test_context"

# Unit test: verify type inference sets correct types on local variable declarations
class TestTypeInferenceLocalVars < Minitest::Test

  def test_local_var_with_float_expression_gets_float_type
    source = <<~Walrus
      func add(a float, b float) float {
        var c = a + b;
        return c;
      }
    Walrus

    # Run up through type inference
    result = [
      Walrus::Tokenizer,
      Walrus::Parser,
      Walrus::FoldConstants,
      Walrus::DeinitializeVariableDeclarations,
      Walrus::ResolveVariableScopes,
      Walrus::InferAndCheckTypes
    ].reduce(source) { |res, pass| pass.new.run(res) }

    # Find the local var declaration
    func = result.statements.find { |stmt| stmt.is_a?(Function) && stmt.name == "add" }
    var_decl = func.body.first

    assert_equal "c", var_decl.name
    assert_equal "float", var_decl.type, "Type inference should set local var decl type to 'float'"
  end

  def test_local_var_with_int_expression_gets_int_type
    source = <<~Walrus
      func add(a int, b int) int {
        var c = a + b;
        return c;
      }
    Walrus

    result = [
      Walrus::Tokenizer,
      Walrus::Parser,
      Walrus::FoldConstants,
      Walrus::DeinitializeVariableDeclarations,
      Walrus::ResolveVariableScopes,
      Walrus::InferAndCheckTypes
    ].reduce(source) { |res, pass| pass.new.run(res) }

    func = result.statements.find { |stmt| stmt.is_a?(Function) && stmt.name == "add" }
    var_decl = func.body.first

    assert_equal "c", var_decl.name
    assert_equal "int", var_decl.type, "Type inference should set local var decl type to 'int'"
  end
end
