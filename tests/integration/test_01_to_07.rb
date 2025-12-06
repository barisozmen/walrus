require_relative "../test_context"
require_relative "../../compiler_passes/01_tokenizer"
require_relative "../../compiler_passes/02_parser"

class Test01To07 < Minitest::Test
  auto_test do |input, expected|
    source_code = read_from_fixtures(input)
    state = source_code.dup

    passes = [
      Walrus::Tokenizer,
      Walrus::Parser,
      #
      Walrus::FoldConstants,
      Walrus::DeinitializeVariableDeclarations,
      Walrus::ResolveVariableScopes,
      Walrus::GatherTopLevelStatementsIntoMain,
      Walrus::EnsureAllFunctionsHaveExplicitReturns
    ]

    result = passes.reduce(state) do |state, pass|
      pass.new.run(state)
    end

    assert_equal expected, result
  end

  def read_from_fixtures(input)
    File.read(File.join(__dir__, "../fixtures/#{input}"))
  end

  TESTCASES = {
    "fact.wl" =>
    
    Program.new([
      Function.new('fact', [Parameter.new('n')], [
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
        ),
        Return.new(IntegerLiteral.new(0))
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
        ),
        Return.new(IntegerLiteral.new(0))
      ])
    ])
  }

  generate_tests
end
