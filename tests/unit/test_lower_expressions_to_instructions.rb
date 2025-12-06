require_relative '../test_context'

class TestLowerExpressionsToInstructions < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::LowerExpressionsToInstructions.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    # Literals
    IntegerLiteral.new(42) =>
      EXPR.new([PUSH.new(42)]),

    # Variables
    LocalName.new('x') =>
      EXPR.new([LOAD_LOCAL.new('x')]),

    GlobalName.new('x') =>
      EXPR.new([LOAD_GLOBAL.new('x')]),

    # Binary operations
    BinOp.new('+', IntegerLiteral.new(10), IntegerLiteral.new(20)) =>
      EXPR.new([PUSH.new(10), PUSH.new(20), ADD.new]),

    BinOp.new('*', LocalName.new('x'), IntegerLiteral.new(2)) =>
      EXPR.new([LOAD_LOCAL.new('x'), PUSH.new(2), MUL.new]),

    BinOp.new('<', GlobalName.new('x'), IntegerLiteral.new(10)) =>
      EXPR.new([LOAD_GLOBAL.new('x'), PUSH.new(10), LT.new]),

    # Nested binary operations
    BinOp.new('+', BinOp.new('*', IntegerLiteral.new(2), IntegerLiteral.new(3)), IntegerLiteral.new(4)) =>
      EXPR.new([PUSH.new(2), PUSH.new(3), MUL.new, PUSH.new(4), ADD.new]),

    # Unary operations
    UnaryOp.new('-', LocalName.new('x')) =>
      EXPR.new([LOAD_LOCAL.new('x'), NEG.new]),

    UnaryOp.new('!', LocalName.new('flag')) =>
      EXPR.new([LOAD_LOCAL.new('flag'), NOT.new]),

    # Function calls
    Call.new('fact', [IntegerLiteral.new(5)]) =>
      EXPR.new([PUSH.new(5), CALL.new('fact', 1)]),

    Call.new('add', [LocalName.new('x'), LocalName.new('y')]) =>
      EXPR.new([LOAD_LOCAL.new('x'), LOAD_LOCAL.new('y'), CALL.new('add', 2)]),

    # Complete statements
    Print.new(BinOp.new('+', IntegerLiteral.new(10), IntegerLiteral.new(20))) =>
      Print.new(EXPR.new([PUSH.new(10), PUSH.new(20), ADD.new])),

    Return.new(BinOp.new('*', LocalName.new('n'), IntegerLiteral.new(2))) =>
      Return.new(EXPR.new([LOAD_LOCAL.new('n'), PUSH.new(2), MUL.new])),

    # Assignment (lvalue not transformed, rvalue transformed)
    Assignment.new(GlobalName.new('x'), BinOp.new('+', GlobalName.new('x'), IntegerLiteral.new(1))) =>
      Assignment.new(GlobalName.new('x'), EXPR.new([LOAD_GLOBAL.new('x'), PUSH.new(1), ADD.new])),

    # Control flow with expressions
    While.new(
      BinOp.new('<', GlobalName.new('x'), IntegerLiteral.new(10)),
      [Print.new(GlobalName.new('x'))]
    ) =>
      While.new(
        EXPR.new([LOAD_GLOBAL.new('x'), PUSH.new(10), LT.new]),
        [Print.new(EXPR.new([LOAD_GLOBAL.new('x')]))]
      ),

    # Function with expression
    Function.new('double', ['x'], [
      Return.new(BinOp.new('*', LocalName.new('x'), IntegerLiteral.new(2)))
    ]) =>
      Function.new('double', ['x'], [
        Return.new(EXPR.new([LOAD_LOCAL.new('x'), PUSH.new(2), MUL.new]))
      ]),

    # Complete program
    Program.new([
      GlobalVarDeclarationWithInit.new('x', IntegerLiteral.new(1)),
      Print.new(BinOp.new('+', GlobalName.new('x'), IntegerLiteral.new(1)))
    ]) =>
      Program.new([
        GlobalVarDeclarationWithInit.new('x', EXPR.new([PUSH.new(1)])),
        Print.new(EXPR.new([LOAD_GLOBAL.new('x'), PUSH.new(1), ADD.new]))
      ]),

    # FloatLiteral
    FloatLiteral.new(1.5) =>
      EXPR.new([PUSH.new(1.5)])
  }

  generate_tests
end
