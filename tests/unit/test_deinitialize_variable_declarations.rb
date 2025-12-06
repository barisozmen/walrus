require_relative "../test_context"

class DeinitializeVariableDeclarationsTest < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::DeinitializeVariableDeclarations.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    # Simple integer initialization
    VarDeclarationWithInit.new('a', IntegerLiteral.new(1)) =>
      MultipleStatements.new([
        VarDeclarationWithoutInit.new('a'),
        Assignment.new(Name.new('a'), IntegerLiteral.new(1))
      ]),



    Program.new([
      Function.new('fact', ['n'], [
        VarDeclarationWithInit.new('x', IntegerLiteral.new(1)),
      ]),
    ]) =>
      Program.new([
        Function.new('fact', ['n'], [
          VarDeclarationWithoutInit.new('x'),
          Assignment.new(Name.new('x'), IntegerLiteral.new(1)),
        ]),
      ]),


    
    Program.new([
      Function.new('fact', ['n'], [
        If.new(
          BinOp.new('<', Name.new('n'), IntegerLiteral.new(2)),
          [Return.new(IntegerLiteral.new(1))],
          [
            VarDeclarationWithInit.new('x', IntegerLiteral.new(1)),
          ]
        )
      ]),
    ]) =>
      Program.new([
        Function.new('fact', ['n'], [
          If.new(
            BinOp.new('<', Name.new('n'), IntegerLiteral.new(2)),
            [Return.new(IntegerLiteral.new(1))],
            [
              VarDeclarationWithoutInit.new('x'),
              Assignment.new(Name.new('x'), IntegerLiteral.new(1)),
            ]
          )
        ]),
      ]),



    Program.new([
      Function.new('fact', ['n'], [
        If.new(
          BinOp.new('<', Name.new('n'), IntegerLiteral.new(2)),
          [Return.new(IntegerLiteral.new(1))],
          [
            VarDeclarationWithInit.new('x', IntegerLiteral.new(1)),
            VarDeclarationWithInit.new('result', IntegerLiteral.new(1)),
            While.new(
              BinOp.new('<', Name.new('x'), Name.new('n')),
              [
                Assignment.new(Name.new('result'), BinOp.new('*', Name.new('result'), Name.new('x'))),
                Assignment.new(Name.new('x'), BinOp.new('+', Name.new('x'), IntegerLiteral.new(1)))
              ]
            ),
            Return.new(BinOp.new('*', Name.new('result'), Name.new('n')))
          ]
        )
      ]),
      VarDeclarationWithInit.new('x', IntegerLiteral.new(1)),
      While.new(
        BinOp.new('<', Name.new('x'), IntegerLiteral.new(10)),
        [
          Print.new(Call.new('fact', [Name.new('x')])),
          Assignment.new(Name.new('x'), BinOp.new('+', Name.new('x'), IntegerLiteral.new(1)))
        ]
      )
    ]) =>
      Program.new([
        Function.new('fact', ['n'], [
          If.new(
            BinOp.new('<', Name.new('n'), IntegerLiteral.new(2)),
            [Return.new(IntegerLiteral.new(1))],
            [
              VarDeclarationWithoutInit.new('x'),
              Assignment.new(Name.new('x'), IntegerLiteral.new(1)),
              VarDeclarationWithoutInit.new('result'),
              Assignment.new(Name.new('result'), IntegerLiteral.new(1)),
              While.new(
                BinOp.new('<', Name.new('x'), Name.new('n')),
                [
                  Assignment.new(Name.new('result'), BinOp.new('*', Name.new('result'), Name.new('x'))),
                  Assignment.new(Name.new('x'), BinOp.new('+', Name.new('x'), IntegerLiteral.new(1)))
                ]
              ),
              Return.new(BinOp.new('*', Name.new('result'), Name.new('n')))
            ]
          )
        ]),
        VarDeclarationWithoutInit.new('x'),
        Assignment.new(Name.new('x'), IntegerLiteral.new(1)),
        While.new(
          BinOp.new('<', Name.new('x'), IntegerLiteral.new(10)),
          [
            Print.new(Call.new('fact', [Name.new('x')])),
            Assignment.new(Name.new('x'), BinOp.new('+', Name.new('x'), IntegerLiteral.new(1)))
          ]
        )
      ])
  }

  generate_tests
end
