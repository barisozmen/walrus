require_relative '../test_context'

class TestMergeStatementsIntoBasicBlocks < Minitest::Test
  def setup
    @pass = Walrus::MergeStatementsIntoBasicBlocks.new
  end

  def test_single_statement_becomes_single_block
    input = [STATEMENT.new([PUSH.new(42), PRINT.new])]
    result = @pass.run(input)

    assert_equal 1, result.length
    assert_instance_of BLOCK, result[0]
    assert_equal 'L0', result[0].label
    assert_equal [PUSH.new(42), PRINT.new], result[0].instructions
  end

  def test_adjacent_statements_merge_into_single_block
    input = [
      STATEMENT.new([PUSH.new(10), STORE_GLOBAL.new('x')]),
      STATEMENT.new([PUSH.new(20), STORE_GLOBAL.new('y')])
    ]
    result = @pass.run(input)

    assert_equal 1, result.length
    assert_instance_of BLOCK, result[0]
    assert_equal [
      PUSH.new(10), STORE_GLOBAL.new('x'),
      PUSH.new(20), STORE_GLOBAL.new('y')
    ], result[0].instructions
  end

  def test_multiple_adjacent_statements_merge
    input = [
      STATEMENT.new([PUSH.new(1), STORE_LOCAL.new('a')]),
      STATEMENT.new([PUSH.new(2), STORE_LOCAL.new('b')]),
      STATEMENT.new([PUSH.new(3), STORE_LOCAL.new('c')])
    ]
    result = @pass.run(input)

    assert_equal 1, result.length
    assert_equal [
      PUSH.new(1), STORE_LOCAL.new('a'),
      PUSH.new(2), STORE_LOCAL.new('b'),
      PUSH.new(3), STORE_LOCAL.new('c')
    ], result[0].instructions
  end

  def test_non_statement_nodes_create_separate_blocks
    input = [
      STATEMENT.new([PUSH.new(1), STORE_GLOBAL.new('x')]),
      GlobalVarDeclarationWithoutInit.new('y'),
      STATEMENT.new([PUSH.new(2), STORE_GLOBAL.new('y')])
    ]
    result = @pass.run(input)

    assert_equal 3, result.length
    assert_instance_of BLOCK, result[0]
    assert_instance_of GlobalVarDeclarationWithoutInit, result[1]
    assert_instance_of BLOCK, result[2]
  end

  def test_function_body_converted_to_blocks
    input = Function.new('test', [], [
      STATEMENT.new([PUSH.new(42), RETURN.new])
    ])
    result = @pass.run(input)

    assert_instance_of Function, result
    assert_equal 1, result.body.length
    assert_instance_of BLOCK, result.body[0]
    assert_equal [PUSH.new(42), RETURN.new], result.body[0].instructions
  end

  def test_if_then_else_blocks
    input = If.new(
      EXPR.new([LOAD_LOCAL.new('x'), PUSH.new(10), LT.new]),
      [STATEMENT.new([PUSH.new(1), RETURN.new])],
      [STATEMENT.new([PUSH.new(2), RETURN.new])]
    )
    result = @pass.run(input)

    assert_instance_of If, result
    assert_equal 1, result.then_block.length
    assert_instance_of BLOCK, result.then_block[0]
    assert_equal 1, result.else_block.length
    assert_instance_of BLOCK, result.else_block[0]
  end

  def test_while_body_converted_to_block
    input = While.new(
      EXPR.new([LOAD_LOCAL.new('x'), PUSH.new(10), LT.new]),
      [STATEMENT.new([LOAD_LOCAL.new('x'), PUSH.new(1), ADD.new, STORE_LOCAL.new('x')])]
    )
    result = @pass.run(input)

    assert_instance_of While, result
    assert_equal 1, result.body.length
    assert_instance_of BLOCK, result.body[0]
  end

  def test_statements_before_and_after_control_flow
    input = [
      STATEMENT.new([PUSH.new(1), STORE_GLOBAL.new('x')]),
      While.new(
        EXPR.new([LOAD_GLOBAL.new('x'), PUSH.new(10), LT.new]),
        [STATEMENT.new([LOAD_GLOBAL.new('x'), PUSH.new(1), ADD.new, STORE_GLOBAL.new('x')])]
      ),
      STATEMENT.new([PUSH.new(0), RETURN.new])
    ]
    result = @pass.run(input)

    assert_equal 3, result.length
    assert_instance_of BLOCK, result[0]
    assert_instance_of While, result[1]
    assert_instance_of BLOCK, result[2]
  end

  def test_program_statements_converted
    input = Program.new([
      GlobalVarDeclarationWithoutInit.new('x'),
      Function.new('main', [], [
        STATEMENT.new([PUSH.new(1), STORE_GLOBAL.new('x')]),
        STATEMENT.new([PUSH.new(0), RETURN.new])
      ])
    ])
    result = @pass.run(input)

    assert_instance_of Program, result
    assert_equal 2, result.statements.length

    func = result.statements[1]
    assert_equal 1, func.body.length
    assert_instance_of BLOCK, func.body[0]
    assert_equal [
      PUSH.new(1), STORE_GLOBAL.new('x'),
      PUSH.new(0), RETURN.new
    ], func.body[0].instructions
  end

  def test_unique_labels_generated
    input = [
      STATEMENT.new([PUSH.new(1)]),
      STATEMENT.new([PUSH.new(2)]),
      GlobalVarDeclarationWithoutInit.new('x'),
      STATEMENT.new([PUSH.new(3)])
    ]
    result = @pass.run(input)

    # Should have 3 blocks with different labels
    blocks = result.select { |stmt| stmt.is_a?(BLOCK) }
    assert_equal 2, blocks.length
    assert_equal 'L0', blocks[0].label
    assert_equal 'L1', blocks[1].label
  end

  def test_nested_control_flow
    input = If.new(
      EXPR.new([LOAD_LOCAL.new('n'), PUSH.new(2), LT.new]),
      [STATEMENT.new([PUSH.new(1), RETURN.new])],
      [
        STATEMENT.new([LOCAL.new('x'), PUSH.new(1), STORE_LOCAL.new('x')]),
        While.new(
          EXPR.new([LOAD_LOCAL.new('x'), LOAD_LOCAL.new('n'), LT.new]),
          [STATEMENT.new([LOAD_LOCAL.new('x'), PUSH.new(1), ADD.new, STORE_LOCAL.new('x')])]
        ),
        STATEMENT.new([LOAD_LOCAL.new('x'), RETURN.new])
      ]
    )
    result = @pass.run(input)

    # Then block should have 1 block
    assert_equal 1, result.then_block.length
    assert_instance_of BLOCK, result.then_block[0]

    # Else block should have: block, while, block
    assert_equal 3, result.else_block.length
    assert_instance_of BLOCK, result.else_block[0]
    assert_instance_of While, result.else_block[1]
    assert_instance_of BLOCK, result.else_block[2]
  end
end
