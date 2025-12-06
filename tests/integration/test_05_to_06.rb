require_relative "../test_context"
require_relative "../../compiler_passes/05_resolve_variable_scopes"
require_relative "../../compiler_passes/06_gather_top_level_statements_into_main"

class TokenizerAndParserTest < Minitest::Test
  auto_test do |ast, expected|
    ast = Walrus::ResolveVariableScopes.new.run(ast)
    ast = Walrus::GatherTopLevelStatementsIntoMain.new.run(ast)
    assert_equal expected, ast
  end

  TESTCASES = {
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
    ]) => Program.new([
      Function.new('fact', ['n'], [
        If.new(
          BinOp.new('<', Name.new('n'), IntegerLiteral.new(2)),
          [Return.new(IntegerLiteral.new(1))],
          [
            LocalVarDeclarationWithoutInit.new('x'),
            Assignment.new(Name.new('x'), IntegerLiteral.new(1)),
            LocalVarDeclarationWithoutInit.new('result'),
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
      GlobalVarDeclarationWithoutInit.new('x'),
      
      Function.new('main', [], [
        Assignment.new(Name.new('x'), IntegerLiteral.new(1)),
        While.new(
          BinOp.new('<', Name.new('x'), IntegerLiteral.new(10)),
          [
            Print.new(Call.new('fact', [Name.new('x')])),
            Assignment.new(Name.new('x'), BinOp.new('+', Name.new('x'), IntegerLiteral.new(1)))
          ]
        )
      ])
    ])
  }

  generate_tests
end
