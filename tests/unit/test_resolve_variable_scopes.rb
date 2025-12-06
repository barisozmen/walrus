require_relative '../test_context'

class TestResolveVariableScopes < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::ResolveVariableScopes.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    # global variable
    Program.new([VarDeclarationWithoutInit.new('x')]) =>
      Program.new([GlobalVarDeclarationWithoutInit.new('x')]),

    # global variable reference
    Program.new([
      VarDeclarationWithoutInit.new('x'),
      Assignment.new(Name.new('x'), IntegerLiteral.new(42))
    ]) =>
      Program.new([
        GlobalVarDeclarationWithoutInit.new('x'),
        Assignment.new(GlobalName.new('x'), IntegerLiteral.new(42))
      ]),

    # function parameter is local
    Program.new([
      Function.new('f', [Parameter.new('y')], [Return.new(Name.new('y'))])
    ]) =>
      Program.new([
        Function.new('f', [Parameter.new('y')], [Return.new(LocalName.new('y'))])
      ]),

    # variable declared in function is local
    Program.new([
      Function.new('f', [Parameter.new('y')], [
        VarDeclarationWithoutInit.new('r'),
        Assignment.new(Name.new('r'), Name.new('y')),
        Return.new(Name.new('r'))
      ])
    ]) =>
      Program.new([
        Function.new('f', [Parameter.new('y')], [
          LocalVarDeclarationWithoutInit.new('r'),
          Assignment.new(LocalName.new('r'), LocalName.new('y')),
          Return.new(LocalName.new('r'))
        ])
      ]),

    # variable declared in function is local
    Program.new([
      Function.new('f', [Parameter.new('y')], [
        VarDeclarationWithInit.new('r', Name.new('y')),
        Return.new(Name.new('r'))
      ])
    ]) =>
      Program.new([
        Function.new('f', [Parameter.new('y')], [
          LocalVarDeclarationWithInit.new('r', LocalName.new('y')),
          Return.new(LocalName.new('r'))
        ])
      ]),

    # function accesses global variable
    Program.new([
      VarDeclarationWithoutInit.new('x'),
      Function.new('f', [Parameter.new('y')], [
        Assignment.new(Name.new('x'), Name.new('y'))
      ])
    ]) =>
      Program.new([
        GlobalVarDeclarationWithoutInit.new('x'),
        Function.new('f', [Parameter.new('y')], [
          Assignment.new(GlobalName.new('x'), LocalName.new('y'))
        ])
      ]),

    # function accesses global variable
    Program.new([
      VarDeclarationWithInit.new('x', IntegerLiteral.new(0)),
      Function.new('f', [Parameter.new('y')], [
        Assignment.new(Name.new('x'), Name.new('y'))
      ])
    ]) =>
      Program.new([
        GlobalVarDeclarationWithInit.new('x', IntegerLiteral.new(0)),
        Function.new('f', [Parameter.new('y')], [
          Assignment.new(GlobalName.new('x'), LocalName.new('y'))
        ])
      ]),

    # variable inside if-block at top level is local
    Program.new([
      VarDeclarationWithoutInit.new('x'),
      If.new(
        BinOp.new('<', Name.new('x'), IntegerLiteral.new(10)),
        [
          VarDeclarationWithoutInit.new('y'),
          Print.new(Name.new('y'))
        ],
        []
      )
    ]) =>
      Program.new([
        GlobalVarDeclarationWithoutInit.new('x'),
        If.new(
          BinOp.new('<', GlobalName.new('x'), IntegerLiteral.new(10)),
          [
            LocalVarDeclarationWithoutInit.new('y'),
            Print.new(LocalName.new('y'))
          ],
          []
        )
      ]),

    # variable inside while-block at top level is local
    Program.new([
      VarDeclarationWithoutInit.new('x'),
      While.new(
        BinOp.new('<', Name.new('x'), IntegerLiteral.new(10)),
        [VarDeclarationWithoutInit.new('y')]
      )
    ]) =>
      Program.new([
        GlobalVarDeclarationWithoutInit.new('x'),
        While.new(
          BinOp.new('<', GlobalName.new('x'), IntegerLiteral.new(10)),
          [LocalVarDeclarationWithoutInit.new('y')]
        )
      ]),

    # shadowing: local variable shadows global
    Program.new([
      VarDeclarationWithoutInit.new('x'),
      Assignment.new(Name.new('x'), IntegerLiteral.new(2)),
      Function.new('f', [Parameter.new('y')], [
        VarDeclarationWithoutInit.new('x'),
        Assignment.new(Name.new('x'), BinOp.new('*', Name.new('y'), Name.new('y'))),
        Return.new(Name.new('x'))
      ]),
      Print.new(Call.new('f', [Name.new('x')]))
    ]) =>
      Program.new([
        GlobalVarDeclarationWithoutInit.new('x'),
        Assignment.new(GlobalName.new('x'), IntegerLiteral.new(2)),
        Function.new('f', [Parameter.new('y')], [
          LocalVarDeclarationWithoutInit.new('x'),
          Assignment.new(LocalName.new('x'), BinOp.new('*', LocalName.new('y'), LocalName.new('y'))),
          Return.new(LocalName.new('x'))
        ]),
        Print.new(Call.new('f', [GlobalName.new('x')]))
      ]),

    # if-block inside function: locals persist
    Program.new([
      Function.new('f', [Parameter.new('x')], [
        If.new(
          BinOp.new('>', Name.new('x'), IntegerLiteral.new(0)),
          [VarDeclarationWithoutInit.new('y')],
          []
        ),
        Return.new(Name.new('y'))
      ])
    ]) =>
      Program.new([
        Function.new('f', [Parameter.new('x')], [
          If.new(
            BinOp.new('>', LocalName.new('x'), IntegerLiteral.new(0)),
            [LocalVarDeclarationWithoutInit.new('y')],
            []
          ),
          Return.new(LocalName.new('y'))
        ])
      ]),

    # nested if-else: locals declared in either branch persist after
    Program.new([
      Function.new('f', [], [
        If.new(
          IntegerLiteral.new(1),
          [VarDeclarationWithoutInit.new('x')],
          [VarDeclarationWithoutInit.new('y')]
        ),
        Assignment.new(Name.new('x'), IntegerLiteral.new(1)),
        Assignment.new(Name.new('y'), IntegerLiteral.new(2))
      ])
    ]) =>
      Program.new([
        Function.new('f', [], [
          If.new(
            IntegerLiteral.new(1),
            [LocalVarDeclarationWithoutInit.new('x')],
            [LocalVarDeclarationWithoutInit.new('y')]
          ),
          Assignment.new(LocalName.new('x'), IntegerLiteral.new(1)),
          Assignment.new(LocalName.new('y'), IntegerLiteral.new(2))
        ])
      ])
  }

  generate_tests
end
