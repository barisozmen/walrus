require_relative "../test_context"
require_relative "../../compiler_passes/02_parser"
require_relative "../../compiler_passes/03_fold_constants"
require_relative "../../compiler_passes/04_deinitialize_variable_declarations"

class TokenizerAndParserTest < Minitest::Test
  auto_test do |ast, expected|
    ast = Walrus::FoldConstants.new.run(ast)
    ast = Walrus::DeinitializeVariableDeclarations.new.run(ast)
    assert_equal expected, ast
  end

  TESTCASES = {
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
