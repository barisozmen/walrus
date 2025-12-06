require_relative '../test_context'
require_relative "../../compiler_passes/02_5_lower_case_to_elsif"

class LowerCaseToElsIfTest < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::LowerCaseToElsIf.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    # Test 1: Simple case with two when branches
    # case x { when 1 { print 1; } when 2 { print 2; } else { print 0; } }
    # => if x == 1 { print 1; } elsif x == 2 { print 2; } else { print 0; }
    Case.new(
      Name.new('x'),
      [
        WhenBranch.new(IntegerLiteral.new(1), [Print.new(IntegerLiteral.new(1))]),
        WhenBranch.new(IntegerLiteral.new(2), [Print.new(IntegerLiteral.new(2))])
      ],
      [Print.new(IntegerLiteral.new(0))]
    ) =>
      ElsIf.new(
        BinOp.new('==', Name.new('x'), IntegerLiteral.new(1)),
        [Print.new(IntegerLiteral.new(1))],
        [
          ElsIfBranch.new(
            BinOp.new('==', Name.new('x'), IntegerLiteral.new(2)),
            [Print.new(IntegerLiteral.new(2))]
          )
        ],
        [Print.new(IntegerLiteral.new(0))]
      ),

    # Test 2: Case with single when branch (no elsif needed)
    # case x { when 1 { print 1; } else { print 0; } }
    # => if x == 1 { print 1; } else { print 0; }
    Case.new(
      Name.new('x'),
      [WhenBranch.new(IntegerLiteral.new(1), [Print.new(IntegerLiteral.new(1))])],
      [Print.new(IntegerLiteral.new(0))]
    ) =>
      ElsIf.new(
        BinOp.new('==', Name.new('x'), IntegerLiteral.new(1)),
        [Print.new(IntegerLiteral.new(1))],
        [],
        [Print.new(IntegerLiteral.new(0))]
      ),

    # Test 3: Case without else clause
    # case x { when 1 { print 1; } when 2 { print 2; } }
    # => if x == 1 { print 1; } elsif x == 2 { print 2; }
    Case.new(
      Name.new('x'),
      [
        WhenBranch.new(IntegerLiteral.new(1), [Print.new(IntegerLiteral.new(1))]),
        WhenBranch.new(IntegerLiteral.new(2), [Print.new(IntegerLiteral.new(2))])
      ],
      []
    ) =>
      ElsIf.new(
        BinOp.new('==', Name.new('x'), IntegerLiteral.new(1)),
        [Print.new(IntegerLiteral.new(1))],
        [
          ElsIfBranch.new(
            BinOp.new('==', Name.new('x'), IntegerLiteral.new(2)),
            [Print.new(IntegerLiteral.new(2))]
          )
        ],
        []
      ),

    # Test 4: Case with multiple when branches
    # case x { when 1 {...} when 2 {...} when 3 {...} else {...} }
    Case.new(
      Name.new('x'),
      [
        WhenBranch.new(IntegerLiteral.new(1), [Print.new(IntegerLiteral.new(100))]),
        WhenBranch.new(IntegerLiteral.new(2), [Print.new(IntegerLiteral.new(200))]),
        WhenBranch.new(IntegerLiteral.new(3), [Print.new(IntegerLiteral.new(300))])
      ],
      [Print.new(IntegerLiteral.new(999))]
    ) =>
      ElsIf.new(
        BinOp.new('==', Name.new('x'), IntegerLiteral.new(1)),
        [Print.new(IntegerLiteral.new(100))],
        [
          ElsIfBranch.new(
            BinOp.new('==', Name.new('x'), IntegerLiteral.new(2)),
            [Print.new(IntegerLiteral.new(200))]
          ),
          ElsIfBranch.new(
            BinOp.new('==', Name.new('x'), IntegerLiteral.new(3)),
            [Print.new(IntegerLiteral.new(300))]
          )
        ],
        [Print.new(IntegerLiteral.new(999))]
      ),

    # Test 5: Empty case (edge case - no when branches)
    # case x { else { print 0; } }
    # => if x == x { } else { print 0; } (always goes to else)
    Case.new(
      Name.new('x'),
      [],
      [Print.new(IntegerLiteral.new(0))]
    ) =>
      If.new(
        BinOp.new('==', Name.new('x'), Name.new('x')),
        [],
        [Print.new(IntegerLiteral.new(0))]
      )
  }

  generate_tests
end
