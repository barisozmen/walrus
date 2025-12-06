require_relative "../test_context"
require_relative "../../compiler_passes/01_tokenizer"
require_relative "../../compiler_passes/02_parser"

class TokenizerAndParserTest < Minitest::Test
  auto_test do |input, expected|
    source = File.read(File.join(__dir__, "../fixtures/#{input}"))
    tokens = Walrus::Tokenizer.new.run(source)
    ast = Walrus::Parser.new.run(tokens)
    assert_equal expected, ast
  end

  TESTCASES = {
    "fact.wl" => Program.new([
      Function.new('fact', [Parameter.new('n')], [
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
    ]),
    
    "factre.wl" => Program.new([
      Function.new('fact', [Parameter.new('n')], [
        If.new(
          BinOp.new('==', Name.new('n'), IntegerLiteral.new(0)),
          [Return.new(IntegerLiteral.new(1))],
          [Return.new(BinOp.new('*', Name.new('n'), Call.new('fact', [BinOp.new('-', Name.new('n'), IntegerLiteral.new(1))])))]
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
    ])
  }

  generate_tests
end
