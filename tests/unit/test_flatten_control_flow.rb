require_relative '../test_context'

class TestFlattenControlFlow < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::FlattenControlFlow.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    # block with RETURN unchanged
    [BLOCK.new('L0', [PUSH.new(42), RETURN.new])] =>
      [BLOCK.new('L0', [PUSH.new(42), RETURN.new])],

    # block without RETURN gets GOTO
    [
      BLOCK.new('L0', [PUSH.new(1), STORE_GLOBAL.new('x')]),
      BLOCK.new('L1', [PUSH.new(0), RETURN.new])
    ] =>
      [
        BLOCK.new('L1', [PUSH.new(1), STORE_GLOBAL.new('x'), GOTO.new('L0')]),
        BLOCK.new('L0', [PUSH.new(0), RETURN.new])
      ],

    # if creates test block with CBRANCH
    If.new(
      EXPR.new([LOAD_LOCAL.new('x'), PUSH.new(10), LT.new]),
      [BLOCK.new('L0', [PUSH.new(1), RETURN.new])],
      [BLOCK.new('L1', [PUSH.new(2), RETURN.new])]
    ) =>
      [
        BLOCK.new('L0', [LOAD_LOCAL.new('x'), PUSH.new(10), LT.new, CBRANCH.new('L1', 'L2')]),
        BLOCK.new('L1', [PUSH.new(1), RETURN.new]),
        BLOCK.new('L2', [PUSH.new(2), RETURN.new])
      ],

    # while creates loop with CBRANCH
    While.new(
      EXPR.new([LOAD_LOCAL.new('x'), PUSH.new(10), LT.new]),
      [BLOCK.new('L0', [LOAD_LOCAL.new('x'), PUSH.new(1), ADD.new, STORE_LOCAL.new('x')])]
    ) =>
      [
        BLOCK.new('L0', [LOAD_LOCAL.new('x'), PUSH.new(10), LT.new, CBRANCH.new('L1', nil)]),
        BLOCK.new('L1', [LOAD_LOCAL.new('x'), PUSH.new(1), ADD.new, STORE_LOCAL.new('x'), GOTO.new('L0')])
      ],

    # nested if properly links blocks
    If.new(
      EXPR.new([LOAD_LOCAL.new('n'), PUSH.new(2), LT.new]),
      [BLOCK.new('L0', [PUSH.new(1), RETURN.new])],
      [
        If.new(
          EXPR.new([LOAD_LOCAL.new('n'), PUSH.new(10), LT.new]),
          [BLOCK.new('L1', [PUSH.new(2), RETURN.new])],
          [BLOCK.new('L2', [PUSH.new(3), RETURN.new])]
        )
      ]
    ) =>
      [
        BLOCK.new('L0', [LOAD_LOCAL.new('n'), PUSH.new(2), LT.new, CBRANCH.new('L1', 'L2')]),
        BLOCK.new('L1', [PUSH.new(1), RETURN.new]),
        BLOCK.new('L2', [LOAD_LOCAL.new('n'), PUSH.new(10), LT.new, CBRANCH.new('L3', 'L4')]),
        BLOCK.new('L3', [PUSH.new(2), RETURN.new]),
        BLOCK.new('L4', [PUSH.new(3), RETURN.new])
      ],

    # Edge case 1: break in simple loop jumps to next_label (exit)
    While.new(
      EXPR.new([LOAD_LOCAL.new('x'), PUSH.new(10), LT.new]),
      [
        BLOCK.new('L0', [LOAD_LOCAL.new('x'), PUSH.new(1), ADD.new, STORE_LOCAL.new('x')]),
        Break.new
      ]
    ) =>
      [
        BLOCK.new('L0', [LOAD_LOCAL.new('x'), PUSH.new(10), LT.new, CBRANCH.new('L2', nil)]),
        BLOCK.new('L2', [LOAD_LOCAL.new('x'), PUSH.new(1), ADD.new, STORE_LOCAL.new('x'), GOTO.new('L1')]),
        BLOCK.new('L1', [GOTO.new(nil)])
      ],

    # Edge case 2: continue in simple loop jumps to test_label (condition)
    While.new(
      EXPR.new([LOAD_LOCAL.new('x'), PUSH.new(10), LT.new]),
      [
        BLOCK.new('L0', [LOAD_LOCAL.new('x'), PUSH.new(1), ADD.new, STORE_LOCAL.new('x')]),
        Continue.new,
        BLOCK.new('L1', [PUSH.new(99), STORE_LOCAL.new('x')])  # unreachable
      ]
    ) =>
      [
        BLOCK.new('L0', [LOAD_LOCAL.new('x'), PUSH.new(10), LT.new, CBRANCH.new('L3', nil)]),
        BLOCK.new('L3', [LOAD_LOCAL.new('x'), PUSH.new(1), ADD.new, STORE_LOCAL.new('x'), GOTO.new('L2')]),
        BLOCK.new('L2', [GOTO.new('L0')]),
        BLOCK.new('L1', [PUSH.new(99), STORE_LOCAL.new('x'), GOTO.new('L0')])
      ],

    # Edge case 3: nested loops - break/continue affect only innermost loop
    While.new(
      EXPR.new([LOAD_LOCAL.new('x'), PUSH.new(10), LT.new]),
      [
        BLOCK.new('L0', [LOAD_LOCAL.new('x'), PUSH.new(1), ADD.new, STORE_LOCAL.new('x')]),
        While.new(
          EXPR.new([LOAD_LOCAL.new('y'), PUSH.new(5), LT.new]),
          [
            BLOCK.new('L1', [LOAD_LOCAL.new('y'), PUSH.new(1), ADD.new, STORE_LOCAL.new('y')]),
            Break.new  # breaks inner loop, not outer
          ]
        )
      ]
    ) =>
      [
        BLOCK.new('L0', [LOAD_LOCAL.new('x'), PUSH.new(10), LT.new, CBRANCH.new('L4', nil)]),
        BLOCK.new('L4', [LOAD_LOCAL.new('x'), PUSH.new(1), ADD.new, STORE_LOCAL.new('x'), GOTO.new('L1')]),
        BLOCK.new('L1', [LOAD_LOCAL.new('y'), PUSH.new(5), LT.new, CBRANCH.new('L3', 'L0')]),
        BLOCK.new('L3', [LOAD_LOCAL.new('y'), PUSH.new(1), ADD.new, STORE_LOCAL.new('y'), GOTO.new('L2')]),
        BLOCK.new('L2', [GOTO.new('L0')])  # break jumps to L0 (outer loop continues)
      ]
  }

  generate_tests
end
