require_relative '../test_context'
require_relative "../../compiler_passes/03_5_lower_for_loops_to_while_loops"

class LowerForLoopsToWhileLoopsTest < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::LowerForLoopsToWhileLoops.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    # for (var i = 0; i < 10; i = i + 1) { print i; }
    # => var i = 0; while i < 10 { print i; i = i + 1; }
    ForLoop.new(
      VarDeclarationWithInit.new('i', IntegerLiteral.new(0)),
      BinOp.new('<', Name.new('i'), IntegerLiteral.new(10)),
      Assignment.new(Name.new('i'), BinOp.new('+', Name.new('i'), IntegerLiteral.new(1))),
      [Print.new(Name.new('i'))]
    ) =>
      MultipleStatements.new([
        VarDeclarationWithInit.new('i', IntegerLiteral.new(0)),
        While.new(
          BinOp.new('<', Name.new('i'), IntegerLiteral.new(10)),
          [Print.new(Name.new('i')), Assignment.new(Name.new('i'), BinOp.new('+', Name.new('i'), IntegerLiteral.new(1)))]
        )
      ]),

    # for (x = 0; x < 5; x = x + 1) { print x; }
    # => x = 0; while x < 5 { print x; x = x + 1; }
    ForLoop.new(
      Assignment.new(Name.new('x'), IntegerLiteral.new(0)),
      BinOp.new('<', Name.new('x'), IntegerLiteral.new(5)),
      Assignment.new(Name.new('x'), BinOp.new('+', Name.new('x'), IntegerLiteral.new(1))),
      [Print.new(Name.new('x'))]
    ) =>
      MultipleStatements.new([
        Assignment.new(Name.new('x'), IntegerLiteral.new(0)),
        While.new(
          BinOp.new('<', Name.new('x'), IntegerLiteral.new(5)),
          [Print.new(Name.new('x')), Assignment.new(Name.new('x'), BinOp.new('+', Name.new('x'), IntegerLiteral.new(1)))]
        )
      ]),

    # for (; i < 10; i = i + 1) { print i; }
    # => while i < 10 { print i; i = i + 1; }
    ForLoop.new(
      nil,
      BinOp.new('<', Name.new('i'), IntegerLiteral.new(10)),
      Assignment.new(Name.new('i'), BinOp.new('+', Name.new('i'), IntegerLiteral.new(1))),
      [Print.new(Name.new('i'))]
    ) =>
      MultipleStatements.new([
        While.new(
          BinOp.new('<', Name.new('i'), IntegerLiteral.new(10)),
          [Print.new(Name.new('i')), Assignment.new(Name.new('i'), BinOp.new('+', Name.new('i'), IntegerLiteral.new(1)))]
        )
      ]),

    # Nested for loops
    ForLoop.new(
      VarDeclarationWithInit.new('i', IntegerLiteral.new(0)),
      BinOp.new('<', Name.new('i'), IntegerLiteral.new(3)),
      Assignment.new(Name.new('i'), BinOp.new('+', Name.new('i'), IntegerLiteral.new(1))),
      [
        ForLoop.new(
          VarDeclarationWithInit.new('j', IntegerLiteral.new(0)),
          BinOp.new('<', Name.new('j'), IntegerLiteral.new(3)),
          Assignment.new(Name.new('j'), BinOp.new('+', Name.new('j'), IntegerLiteral.new(1))),
          [Print.new(Name.new('j'))]
        )
      ]
    ) =>
      MultipleStatements.new([
        VarDeclarationWithInit.new('i', IntegerLiteral.new(0)),
        While.new(
          BinOp.new('<', Name.new('i'), IntegerLiteral.new(3)),
          [
            VarDeclarationWithInit.new('j', IntegerLiteral.new(0)),
            While.new(
              BinOp.new('<', Name.new('j'), IntegerLiteral.new(3)),
              [Print.new(Name.new('j')), Assignment.new(Name.new('j'), BinOp.new('+', Name.new('j'), IntegerLiteral.new(1)))]
            ),
            Assignment.new(Name.new('i'), BinOp.new('+', Name.new('i'), IntegerLiteral.new(1)))
          ]
        )
      ]),

    # Empty body
    ForLoop.new(
      VarDeclarationWithInit.new('i', IntegerLiteral.new(0)),
      BinOp.new('<', Name.new('i'), IntegerLiteral.new(10)),
      Assignment.new(Name.new('i'), BinOp.new('+', Name.new('i'), IntegerLiteral.new(1))),
      []
    ) =>
      MultipleStatements.new([
        VarDeclarationWithInit.new('i', IntegerLiteral.new(0)),
        While.new(
          BinOp.new('<', Name.new('i'), IntegerLiteral.new(10)),
          [Assignment.new(Name.new('i'), BinOp.new('+', Name.new('i'), IntegerLiteral.new(1)))]
        )
      ])
  }

  generate_tests
end
