require_relative '../test_context'
require_relative "../../compiler_passes/02_6_lower_elsif_to_if"

class LowerElsIfToIfTest < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::LowerElsIfToIf.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    # Test 1: Simple elsif with one elsif branch
    # if x < 0 { print -1; } elsif x == 0 { print 0; } else { print 1; }
    # => if x < 0 { print -1; } else { if x == 0 { print 0; } else { print 1; } }
    ElsIf.new(
      BinOp.new('<', Name.new('x'), IntegerLiteral.new(0)),
      [Print.new(IntegerLiteral.new(-1))],
      [
        ElsIfBranch.new(
          BinOp.new('==', Name.new('x'), IntegerLiteral.new(0)),
          [Print.new(IntegerLiteral.new(0))]
        )
      ],
      [Print.new(IntegerLiteral.new(1))]
    ) =>
      If.new(
        BinOp.new('<', Name.new('x'), IntegerLiteral.new(0)),
        [Print.new(IntegerLiteral.new(-1))],
        [If.new(
          BinOp.new('==', Name.new('x'), IntegerLiteral.new(0)),
          [Print.new(IntegerLiteral.new(0))],
          [Print.new(IntegerLiteral.new(1))]
        )]
      ),

    # Test 2: elsif with multiple elsif branches
    # if x == 1 {...} elsif x == 2 {...} elsif x == 3 {...} else {...}
    # => nested if/else/if/else/if/else
    ElsIf.new(
      BinOp.new('==', Name.new('x'), IntegerLiteral.new(1)),
      [Print.new(IntegerLiteral.new(1))],
      [
        ElsIfBranch.new(
          BinOp.new('==', Name.new('x'), IntegerLiteral.new(2)),
          [Print.new(IntegerLiteral.new(2))]
        ),
        ElsIfBranch.new(
          BinOp.new('==', Name.new('x'), IntegerLiteral.new(3)),
          [Print.new(IntegerLiteral.new(3))]
        )
      ],
      [Print.new(IntegerLiteral.new(999))]
    ) =>
      If.new(
        BinOp.new('==', Name.new('x'), IntegerLiteral.new(1)),
        [Print.new(IntegerLiteral.new(1))],
        [If.new(
          BinOp.new('==', Name.new('x'), IntegerLiteral.new(2)),
          [Print.new(IntegerLiteral.new(2))],
          [If.new(
            BinOp.new('==', Name.new('x'), IntegerLiteral.new(3)),
            [Print.new(IntegerLiteral.new(3))],
            [Print.new(IntegerLiteral.new(999))]
          )]
        )]
      ),

    # Test 3: elsif without else clause
    # if x == 1 { print 1; } elsif x == 2 { print 2; }
    # => if x == 1 { print 1; } else { if x == 2 { print 2; } }
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
    ) =>
      If.new(
        BinOp.new('==', Name.new('x'), IntegerLiteral.new(1)),
        [Print.new(IntegerLiteral.new(1))],
        [If.new(
          BinOp.new('==', Name.new('x'), IntegerLiteral.new(2)),
          [Print.new(IntegerLiteral.new(2))],
          []
        )]
      ),

    # Test 4: elsif with no elsif branches (degenerates to simple if)
    # if x < 0 { print -1; } else { print 1; }
    # Should stay as simple if (no elsif branches to lower)
    ElsIf.new(
      BinOp.new('<', Name.new('x'), IntegerLiteral.new(0)),
      [Print.new(IntegerLiteral.new(-1))],
      [],
      [Print.new(IntegerLiteral.new(1))]
    ) =>
      If.new(
        BinOp.new('<', Name.new('x'), IntegerLiteral.new(0)),
        [Print.new(IntegerLiteral.new(-1))],
        [Print.new(IntegerLiteral.new(1))]
      ),

    # Test 5: elsif with complex nested structure in then_block
    # if x == 1 { if y == 2 { print 12; } } elsif x == 3 { print 3; }
    ElsIf.new(
      BinOp.new('==', Name.new('x'), IntegerLiteral.new(1)),
      [If.new(
        BinOp.new('==', Name.new('y'), IntegerLiteral.new(2)),
        [Print.new(IntegerLiteral.new(12))],
        []
      )],
      [
        ElsIfBranch.new(
          BinOp.new('==', Name.new('x'), IntegerLiteral.new(3)),
          [Print.new(IntegerLiteral.new(3))]
        )
      ],
      []
    ) =>
      If.new(
        BinOp.new('==', Name.new('x'), IntegerLiteral.new(1)),
        [If.new(
          BinOp.new('==', Name.new('y'), IntegerLiteral.new(2)),
          [Print.new(IntegerLiteral.new(12))],
          []
        )],
        [If.new(
          BinOp.new('==', Name.new('x'), IntegerLiteral.new(3)),
          [Print.new(IntegerLiteral.new(3))],
          []
        )]
      )
  }

  generate_tests
end
