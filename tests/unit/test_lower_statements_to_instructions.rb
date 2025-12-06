require_relative '../test_context'

class TestLowerStatementsToInstructions < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::LowerStatementsToInstructions.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    Print.new(EXPR.new([PUSH.new(42)])) =>
      STATEMENT.new([PUSH.new(42), PRINT.new]),

    Return.new(EXPR.new([PUSH.new(1)]), type: :int) =>
      STATEMENT.new([PUSH.new(1), RETURN.new(type: :int)]),

    Assignment.new(LocalName.new('x'), EXPR.new([PUSH.new(10), PUSH.new(20), ADD.new]), type: :int) =>
      STATEMENT.new([PUSH.new(10), PUSH.new(20), ADD.new, STORE_LOCAL.new('x', type: :int)]),

    Assignment.new(GlobalName.new('y'), EXPR.new([LOAD_LOCAL.new('x')]), type: :int) =>
      STATEMENT.new([LOAD_LOCAL.new('x'), STORE_GLOBAL.new('y', type: :int)]),

    LocalVarDeclarationWithoutInit.new('z') =>
      STATEMENT.new([LOCAL.new('z')])
  }

  generate_tests
end
