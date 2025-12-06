require_relative '../test_context'

class TestInferAndCheckTypes < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::InferAndCheckTypes.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    # Test 1: Literal gets type assigned
    Program.new([
      GlobalVarDeclarationWithInit.new('x', IntegerLiteral.new(42))
    ]) =>
      Program.new([
        GlobalVarDeclarationWithInit.new('x',
          IntegerLiteral.new(42).tap { |n| n.type = 'int' }
        ).tap { |n| n.type = 'int' }
      ]),

    # Test 2: Variable with explicit type, name reference gets type
    Program.new([
      GlobalVarDeclarationWithoutInit.new('x').tap { |n| n.type = 'int' },
      Print.new(GlobalName.new('x'))
    ]) =>
      Program.new([
        GlobalVarDeclarationWithoutInit.new('x').tap { |n| n.type = 'int' },
        Print.new(GlobalName.new('x').tap { |n| n.type = 'int' })
      ]),

    # Test 3: BinOp arithmetic (int + int => int)
    Program.new([
      GlobalVarDeclarationWithInit.new('sum',
        BinOp.new('+', IntegerLiteral.new(10), IntegerLiteral.new(20))
      )
    ]) =>
      Program.new([
        GlobalVarDeclarationWithInit.new('sum',
          BinOp.new('+',
            IntegerLiteral.new(10).tap { |n| n.type = 'int' },
            IntegerLiteral.new(20).tap { |n| n.type = 'int' }
          ).tap { |n| n.type = 'int' }
        ).tap { |n| n.type = 'int' }
      ]),

    # Test 4: BinOp comparison (int < int => bool)
    Program.new([
      If.new(
        BinOp.new('<', IntegerLiteral.new(1), IntegerLiteral.new(2)),
        [],
        []
      )
    ]) =>
      Program.new([
        If.new(
          BinOp.new('<',
            IntegerLiteral.new(1).tap { |n| n.type = 'int' },
            IntegerLiteral.new(2).tap { |n| n.type = 'int' }
          ).tap { |n| n.type = 'bool' },
          [],
          []
        )
      ]),

    # Test 5: Assignment with type propagation
    Program.new([
      GlobalVarDeclarationWithoutInit.new('x', type: 'int'),
      Assignment.new(GlobalName.new('x'), IntegerLiteral.new(42))
    ]) =>
      Program.new([
        GlobalVarDeclarationWithoutInit.new('x', type: 'int'),
        Assignment.new(
          GlobalName.new('x').tap { |n| n.type = 'int' },
          IntegerLiteral.new(42).tap { |n| n.type = 'int' }
        )
      ]),

    # Test 6: While loop with bool condition
    Program.new([
      GlobalVarDeclarationWithInit.new('x', IntegerLiteral.new(0)),
      While.new(
        BinOp.new('<', GlobalName.new('x'), IntegerLiteral.new(10)),
        [Assignment.new(GlobalName.new('x'), BinOp.new('+', GlobalName.new('x'), IntegerLiteral.new(1)))]
      )
    ]) =>
      Program.new([
        GlobalVarDeclarationWithInit.new('x', IntegerLiteral.new(0), type: 'int'),
        While.new(
          BinOp.new('<',
            GlobalName.new('x').tap { |n| n.type = 'int' },
            IntegerLiteral.new(10).tap { |n| n.type = 'int' }
          ).tap { |n| n.type = 'bool' },
          [Assignment.new(
            GlobalName.new('x').tap { |n| n.type = 'int' },
            BinOp.new('+',
              GlobalName.new('x').tap { |n| n.type = 'int' },
              IntegerLiteral.new(1).tap { |n| n.type = 'int' }
            ).tap { |n| n.type = 'int' }
          )]
        )
      ]),

    # Test 7: Function with parameters and return
    Program.new([
      Function.new('add1',
        [Parameter.new('x').tap { |p| p.type = 'int' }],
        [Return.new(BinOp.new('+', LocalName.new('x'), IntegerLiteral.new(1)))],
        type: 'int'
      ),
      GlobalVarDeclarationWithInit.new('result',
        Call.new('add1', [IntegerLiteral.new(5)])
      )
    ]) =>
      Program.new([
        Function.new('add1',
          [Parameter.new('x').tap { |p| p.type = 'int' }],
          [Return.new(
            BinOp.new('+',
              LocalName.new('x').tap { |n| n.type = 'int' },
              IntegerLiteral.new(1).tap { |n| n.type = 'int' }
            ).tap { |n| n.type = 'int' }
          )],
          type: 'int'
        ),
        GlobalVarDeclarationWithInit.new('result',
          Call.new('add1', [
            IntegerLiteral.new(5).tap { |n| n.type = 'int' }
          ]).tap { |n| n.type = 'int' }
        ).tap { |n| n.type = 'int' }
      ]),


      # Test 8: Floats
      Program.new([
        GlobalVarDeclarationWithInit.new('x', FloatLiteral.new(1.5)),
        GlobalVarDeclarationWithInit.new('y', FloatLiteral.new(2.5)),
        GlobalVarDeclarationWithInit.new('z', BinOp.new('+', FloatLiteral.new(1.5), FloatLiteral.new(2.5)))
      ]) =>
        Program.new([
          GlobalVarDeclarationWithInit.new('x', FloatLiteral.new(1.5).tap { |n| n.type = 'float' }),
          GlobalVarDeclarationWithInit.new('y', FloatLiteral.new(2.5).tap { |n| n.type = 'float' }),
          GlobalVarDeclarationWithInit.new('z', BinOp.new('+', FloatLiteral.new(1.5).tap { |n| n.type = 'float' }, FloatLiteral.new(2.5).tap { |n| n.type = 'float' })).tap { |n| n.type = 'float' }
        ]),
      
  }

  generate_tests
end

# Error tests - verify type checking works
class TestInferAndCheckTypesErrors < Minitest::Test
  def test_unknown_variable_error
    input = Program.new([Print.new(GlobalName.new('undefined'))])
    assert_raises(CompilerError::TypeError) do
      Walrus::InferAndCheckTypes.new.run(input)
    end
  end

  # Type specifiers are now optional - types can be inferred from assignments
  # So this test is no longer relevant

  def test_unknown_function_error
    input = Program.new([
      GlobalVarDeclarationWithInit.new('x', Call.new('unknown_func', []))
    ])
    assert_raises(CompilerError::TypeError) do
      Walrus::InferAndCheckTypes.new.run(input)
    end
  end
end
