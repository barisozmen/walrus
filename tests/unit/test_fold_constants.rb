require_relative '../test_context'

class FoldConstantsTest < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::FoldConstants.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    # Arithmetic operations
    BinOp.new('+', IntegerLiteral.new(2), IntegerLiteral.new(3)) =>
      IntegerLiteral.new(5),

    BinOp.new('-', IntegerLiteral.new(10), IntegerLiteral.new(3)) =>
      IntegerLiteral.new(7),

    BinOp.new('*', IntegerLiteral.new(23), IntegerLiteral.new(45)) =>
      IntegerLiteral.new(1035),

    BinOp.new('/', IntegerLiteral.new(100), IntegerLiteral.new(5)) =>
      IntegerLiteral.new(20),

    # Comparison operations
    BinOp.new('<', IntegerLiteral.new(3), IntegerLiteral.new(5)) =>
      IntegerLiteral.new(1),

    BinOp.new('<', IntegerLiteral.new(5), IntegerLiteral.new(3)) =>
      IntegerLiteral.new(0),

    BinOp.new('>', IntegerLiteral.new(5), IntegerLiteral.new(3)) =>
      IntegerLiteral.new(1),

    BinOp.new('>', IntegerLiteral.new(3), IntegerLiteral.new(5)) =>
      IntegerLiteral.new(0),

    BinOp.new('==', IntegerLiteral.new(42), IntegerLiteral.new(42)) =>
      IntegerLiteral.new(1),

    BinOp.new('==', IntegerLiteral.new(42), IntegerLiteral.new(43)) =>
      IntegerLiteral.new(0),

    # Nested expressions
    BinOp.new('+', BinOp.new('*', IntegerLiteral.new(2), IntegerLiteral.new(3)), IntegerLiteral.new(4)) =>
      IntegerLiteral.new(10),

    BinOp.new('*', BinOp.new('+', IntegerLiteral.new(2), IntegerLiteral.new(3)), BinOp.new('-', IntegerLiteral.new(10), IntegerLiteral.new(5))) =>
      IntegerLiteral.new(25),

    # Non-constant expressions (should not fold)
    BinOp.new('+', Name.new('x'), IntegerLiteral.new(1)) =>
      BinOp.new('+', Name.new('x'), IntegerLiteral.new(1)),

    BinOp.new('+', IntegerLiteral.new(1), Name.new('y')) =>
      BinOp.new('+', IntegerLiteral.new(1), Name.new('y')),

    BinOp.new('+', Name.new('x'), Name.new('y')) =>
      BinOp.new('+', Name.new('x'), Name.new('y')),

    # Mixed: fold what can be folded
    BinOp.new('+', Name.new('x'), BinOp.new('*', IntegerLiteral.new(2), IntegerLiteral.new(3))) =>
      BinOp.new('+', Name.new('x'), IntegerLiteral.new(6)),

    # Floats
    BinOp.new('+', FloatLiteral.new(1.5), FloatLiteral.new(2.5)) =>
      FloatLiteral.new(4.0),

    BinOp.new('-', FloatLiteral.new(1.5), FloatLiteral.new(2.5)) =>
      FloatLiteral.new(-1.0),

    BinOp.new('*', FloatLiteral.new(1.5), FloatLiteral.new(2.5)) =>
      FloatLiteral.new(3.75),

    BinOp.new('/', FloatLiteral.new(1.5), FloatLiteral.new(2.5)) =>
      FloatLiteral.new(0.6),
  }

  generate_tests
end
