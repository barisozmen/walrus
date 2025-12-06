require_relative "../test_context"

class EnsureAllFunctionsHaveExplicitReturnsTest < Minitest::Test
  auto_test do |input, expected|
    result = Walrus::EnsureAllFunctionsHaveExplicitReturns.new.run(input)
    assert_equal expected, result
  end

  TESTCASES = {
    # Empty function
    Function.new('f', [], [], type: 'int') =>
      Function.new('f', [], [Return.new(IntegerLiteral.new(0))], type: 'int'),

    # Function with single print
    Function.new('f', ['x'], [Print.new(Name.new('x'))], type: 'int') =>
      Function.new('f', ['x'], [
        Print.new(Name.new('x')),
        Return.new(IntegerLiteral.new(0))
      ]),

    # Function already has return
    Function.new('f', ['x'], [Return.new(Name.new('x'))], type: 'int') =>
      Function.new('f', ['x'], [Return.new(Name.new('x'))], type: 'int'),

    # Function with assignment
    Function.new('f', [], [Assignment.new(Name.new('x'), IntegerLiteral.new(42))], type: 'int') =>
      Function.new('f', [], [
        Assignment.new(Name.new('x'), IntegerLiteral.new(42)),
        Return.new(IntegerLiteral.new(0))
      ]),

    # Function with multiple statements
    Function.new('calc', ['a', 'b'], [
      VarDeclarationWithInit.new('sum', BinOp.new('+', Name.new('a'), Name.new('b'))),
      Print.new(Name.new('sum'))
    ], type: 'int') =>
      Function.new('calc', ['a', 'b'], [
        VarDeclarationWithInit.new('sum', BinOp.new('+', Name.new('a'), Name.new('b'))),
        Print.new(Name.new('sum')),
        Return.new(IntegerLiteral.new(0))
      ]),

    # Function with while loop
    Function.new('loop', [], [While.new(IntegerLiteral.new(1), [Print.new(IntegerLiteral.new(1))])], type: 'int') =>
      Function.new('loop', [], [
        While.new(IntegerLiteral.new(1), [Print.new(IntegerLiteral.new(1))]),
        Return.new(IntegerLiteral.new(0))
      ], type: 'int'),

    # Function with if statement
    Function.new('check', ['x'], [If.new(Name.new('x'), [Print.new(IntegerLiteral.new(1))], [Print.new(IntegerLiteral.new(0))])], type: 'int') =>
      Function.new('check', ['x'], [
        If.new(Name.new('x'), [Print.new(IntegerLiteral.new(1))], [Print.new(IntegerLiteral.new(0))]),
        Return.new(IntegerLiteral.new(0))
      ], type: 'int'),

    # Function returning expression
    Function.new('add', ['x', 'y'], [Return.new(BinOp.new('+', Name.new('x'), Name.new('y')))], type: 'int') =>
      Function.new('add', ['x', 'y'], [Return.new(BinOp.new('+', Name.new('x'), Name.new('y')))], type: 'int'),

    # Function returning literal
    Function.new('fortytwo', [], [Return.new(IntegerLiteral.new(42))], type: 'int') =>
      Function.new('fortytwo', [], [Return.new(IntegerLiteral.new(42))], type: 'int'),

    # Function with call and no return
    Function.new('wrapper', ['x'], [
      Call.new('helper', [Name.new('x')])], type: 'int') =>
      Function.new('wrapper', ['x'], [
        Call.new('helper', [Name.new('x')]),
        Return.new(IntegerLiteral.new(0))
      ], type: 'int')
  }

  generate_tests
end
