require_relative '../test_context'
require_relative "../../compiler_passes/03_6_lower_short_circuit_operators"

class LowerShortCircuitOperatorsTest < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::LowerShortCircuitOperators.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    # Test 1: Simple 'and' in if condition
    # if x > 0 and x < 10 { print x; }
    # => if x > 0 { if x < 10 { print x; } }
    If.new(
      BinOp.new('and',
        BinOp.new('>', Name.new('x'), IntegerLiteral.new(0)),
        BinOp.new('<', Name.new('x'), IntegerLiteral.new(10))
      ),
      [Print.new(Name.new('x'))],
      []
    ) =>
      If.new(
        BinOp.new('>', Name.new('x'), IntegerLiteral.new(0)),
        [If.new(
          BinOp.new('<', Name.new('x'), IntegerLiteral.new(10)),
          [Print.new(Name.new('x'))],
          []
        )],
        []
      ),

    # Test 2: Simple 'or' in if condition
    # if x < 0 or x > 10 { print x; }
    # => if x < 0 { print x; } else { if x > 10 { print x; } }
    If.new(
      BinOp.new('or',
        BinOp.new('<', Name.new('x'), IntegerLiteral.new(0)),
        BinOp.new('>', Name.new('x'), IntegerLiteral.new(10))
      ),
      [Print.new(Name.new('x'))],
      []
    ) =>
      If.new(
        BinOp.new('<', Name.new('x'), IntegerLiteral.new(0)),
        [Print.new(Name.new('x'))],
        [If.new(
          BinOp.new('>', Name.new('x'), IntegerLiteral.new(10)),
          [Print.new(Name.new('x'))],
          []
        )]
      ),

    # Test 3: 'and' with else block
    # if x != 0 and y > 5 { print x; } else { print y; }
    # => if x != 0 { if y > 5 { print x; } else { print y; } } else { print y; }
    If.new(
      BinOp.new('and',
        BinOp.new('!=', Name.new('x'), IntegerLiteral.new(0)),
        BinOp.new('>', Name.new('y'), IntegerLiteral.new(5))
      ),
      [Print.new(Name.new('x'))],
      [Print.new(Name.new('y'))]
    ) =>
      If.new(
        BinOp.new('!=', Name.new('x'), IntegerLiteral.new(0)),
        [If.new(
          BinOp.new('>', Name.new('y'), IntegerLiteral.new(5)),
          [Print.new(Name.new('x'))],
          [Print.new(Name.new('y'))]
        )],
        [Print.new(Name.new('y'))]
      ),

    # Test 4: 'and' in while loop
    # while x > 0 and x < 10 { print x; }
    # => while x > 0 { if x < 10 { print x; } }
    While.new(
      BinOp.new('and',
        BinOp.new('>', Name.new('x'), IntegerLiteral.new(0)),
        BinOp.new('<', Name.new('x'), IntegerLiteral.new(10))
      ),
      [Print.new(Name.new('x'))]
    ) =>
      While.new(
        BinOp.new('>', Name.new('x'), IntegerLiteral.new(0)),
        [If.new(
          BinOp.new('<', Name.new('x'), IntegerLiteral.new(10)),
          [Print.new(Name.new('x'))],
          []
        )]
      ),

    # Test 5: Non-logical operators pass through unchanged
    # if x < 10 { print x; }
    # => if x < 10 { print x; }
    If.new(
      BinOp.new('<', Name.new('x'), IntegerLiteral.new(10)),
      [Print.new(Name.new('x'))],
      []
    ) =>
      If.new(
        BinOp.new('<', Name.new('x'), IntegerLiteral.new(10)),
        [Print.new(Name.new('x'))],
        []
      )
  }
end

LowerShortCircuitOperatorsTest.generate_tests
