require_relative "../test_context"

# Unit test: AST transformations must preserve param_types attribute
class TestParamTypesPreservation < Minitest::Test

  def test_ast_transformer_preserves_param_types
    # Create a CALL instruction with param_types set
    original_call = CALL.new('fabs', 1, type: 'float')
    original_call.param_types = ['float']

    # Simulate transformation through a generic transformer
    # (this is what happens in passes 9-11)
    transformer = Class.new do
      include Walrus::AstTransformer
    end.new

    context = {}
    transformed_call = transformer.transform(original_call, context)

    # param_types must be preserved
    assert_equal ['float'], transformed_call.param_types,
                 "param_types must be preserved through AST transformations"
  end

  def test_multiple_transformations_preserve_param_types
    # Test that param_types survives multiple transformation passes
    call = CALL.new('add', 2, type: 'float')
    call.param_types = ['float', 'float']

    # Transform 3 times (simulating passes 9, 10, 11)
    transformer = Class.new do
      include Walrus::AstTransformer
    end.new

    3.times do
      call = transformer.transform(call, {})
    end

    assert_equal ['float', 'float'], call.param_types,
                 "param_types must survive multiple transformations"
  end
end
