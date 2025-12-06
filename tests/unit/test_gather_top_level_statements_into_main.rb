require_relative '../test_context'

class TestGatherTopLevelStatementsIntoMain < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::GatherTopLevelStatementsIntoMain.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    # Empty program - no change
    Program.new([]) =>
      Program.new([]),

    # Only global vars - no main needed
    Program.new([
      GlobalVarDeclarationWithoutInit.new('x'),
      GlobalVarDeclarationWithoutInit.new('y')
    ]) =>
      Program.new([
        GlobalVarDeclarationWithoutInit.new('x'),
        GlobalVarDeclarationWithoutInit.new('y')
      ]),

    # Only functions - no main needed
    Program.new([
      Function.new('test', [], [])
    ]) =>
      Program.new([
        Function.new('test', [], [])
      ]),

    # Single executable statement - create main
    Program.new([
      Print.new(IntegerLiteral.new(42))
    ]) =>
      Program.new([
        Function.new('main', [], [
          Print.new(IntegerLiteral.new(42))
        ])
      ]),

    # Multiple executable statements
    Program.new([
      Print.new(IntegerLiteral.new(1)),
      Print.new(IntegerLiteral.new(2))
    ]) =>
      Program.new([
        Function.new('main', [], [
          Print.new(IntegerLiteral.new(1)),
          Print.new(IntegerLiteral.new(2))
        ])
      ]),

    # Global var + assignment (executable)
    Program.new([
      GlobalVarDeclarationWithoutInit.new('x'),
      Assignment.new(GlobalName.new('x'), IntegerLiteral.new(10))
    ]) =>
      Program.new([
        GlobalVarDeclarationWithoutInit.new('x'),
        Function.new('main', [], [
          Assignment.new(GlobalName.new('x'), IntegerLiteral.new(10))
        ])
      ]),

    # Function + executable statements
    Program.new([
      Function.new('helper', [], [Return.new(IntegerLiteral.new(5))]),
      Print.new(IntegerLiteral.new(42))
    ]) =>
      Program.new([
        Function.new('helper', [], [Return.new(IntegerLiteral.new(5))]),
        Function.new('main', [], [
          Print.new(IntegerLiteral.new(42))
        ])
      ]),

    # Complex mix: globals, functions, executables
    Program.new([
      GlobalVarDeclarationWithoutInit.new('v'),
      Assignment.new(GlobalName.new('v'), IntegerLiteral.new(9)),
      Function.new('square', ['x'], [Return.new(BinOp.new('*', LocalName.new('x'), LocalName.new('x')))]),
      GlobalVarDeclarationWithoutInit.new('result'),
      Assignment.new(GlobalName.new('result'), Call.new('square', [GlobalName.new('v')])),
      Print.new(GlobalName.new('result'))
    ]) =>
      Program.new([
        GlobalVarDeclarationWithoutInit.new('v'),
        Function.new('square', ['x'], [Return.new(BinOp.new('*', LocalName.new('x'), LocalName.new('x')))]),
        GlobalVarDeclarationWithoutInit.new('result'),
        Function.new('main', [], [
          Assignment.new(GlobalName.new('v'), IntegerLiteral.new(9)),
          Assignment.new(GlobalName.new('result'), Call.new('square', [GlobalName.new('v')])),
          Print.new(GlobalName.new('result'))
        ])
      ]),

    # Executable with control flow
    Program.new([
      GlobalVarDeclarationWithoutInit.new('x'),
      If.new(
        GlobalName.new('x'),
        [Print.new(GlobalName.new('x'))],
        [Print.new(IntegerLiteral.new(0))]
      )
    ]) =>
      Program.new([
        GlobalVarDeclarationWithoutInit.new('x'),
        Function.new('main', [], [
          If.new(
            GlobalName.new('x'),
            [Print.new(GlobalName.new('x'))],
            [Print.new(IntegerLiteral.new(0))]
          )
        ])
      ]),

    # Multiple functions and globals, no executables
    Program.new([
      GlobalVarDeclarationWithoutInit.new('a'),
      Function.new('f1', [], []),
      GlobalVarDeclarationWithoutInit.new('b'),
      Function.new('f2', [], [])
    ]) =>
      Program.new([
        GlobalVarDeclarationWithoutInit.new('a'),
        Function.new('f1', [], []),
        GlobalVarDeclarationWithoutInit.new('b'),
        Function.new('f2', [], [])
      ])
  }

  generate_tests
end
