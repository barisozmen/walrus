require_relative '../test_context'
require_relative "../../compiler_passes/02_parser"

class ParserTest < Minitest::Test
  auto_test do |tokens, expected|
    result = Walrus::Parser.new.run(tokens)
    assert_equal expected, result
  end

  TESTCASES = {
    # print 42;
    [Token.new(:PRINT, 'print'), Token.new(:INTEGER, '42'), Token.new(:SEMI, ';')] =>
      Program.new([Print.new(IntegerLiteral.new(42))]),

    # var x = 10;
    [Token.new(:VAR, 'var'), Token.new(:NAME, 'x'), Token.new(:ASSIGN, '='), Token.new(:INTEGER, '10'), Token.new(:SEMI, ';')] =>
      Program.new([VarDeclarationWithInit.new('x', IntegerLiteral.new(10))]),

    # x = 20;
    [Token.new(:NAME, 'x'), Token.new(:ASSIGN, '='), Token.new(:INTEGER, '20'), Token.new(:SEMI, ';')] =>
      Program.new([Assignment.new(Name.new('x'), IntegerLiteral.new(20))]),

    # if x > 0 { print x; } else { print 0; }
    [Token.new(:IF, 'if'), Token.new(:NAME, 'x'), Token.new(:GT, '>'), Token.new(:INTEGER, '0'), Token.new(:LBRACE, '{'), Token.new(:PRINT, 'print'), Token.new(:NAME, 'x'), Token.new(:SEMI, ';'), Token.new(:RBRACE, '}'), Token.new(:ELSE, 'else'), Token.new(:LBRACE, '{'), Token.new(:PRINT, 'print'), Token.new(:INTEGER, '0'), Token.new(:SEMI, ';'), Token.new(:RBRACE, '}')] =>
      Program.new([If.new(BinOp.new('>', Name.new('x'), IntegerLiteral.new(0)), [Print.new(Name.new('x'))], [Print.new(IntegerLiteral.new(0))])]),

    # while x > 0 { x = x + 1; }
    [Token.new(:WHILE, 'while'), Token.new(:NAME, 'x'), Token.new(:GT, '>'), Token.new(:INTEGER, '0'), Token.new(:LBRACE, '{'), Token.new(:NAME, 'x'), Token.new(:ASSIGN, '='), Token.new(:NAME, 'x'), Token.new(:PLUS, '+'), Token.new(:INTEGER, '1'), Token.new(:SEMI, ';'), Token.new(:RBRACE, '}')] =>
      Program.new([While.new(BinOp.new('>', Name.new('x'), IntegerLiteral.new(0)), [Assignment.new(Name.new('x'), BinOp.new('+', Name.new('x'), IntegerLiteral.new(1)))])]),

    # Floats
    [Token.new(:PRINT, 'print'), Token.new(:FLOAT, '3.14'), Token.new(:SEMI, ';')] =>
      Program.new([Print.new(FloatLiteral.new(3.14))]),

    [Token.new(:IF, 'if'), Token.new(:NAME, 'x'), Token.new(:GT, '>'), Token.new(:FLOAT, '0.1'), Token.new(:LBRACE, '{'), Token.new(:PRINT, 'print'), Token.new(:NAME, 'x'), Token.new(:SEMI, ';'), Token.new(:RBRACE, '}'), Token.new(:ELSE, 'else'), Token.new(:LBRACE, '{'), Token.new(:PRINT, 'print'), Token.new(:FLOAT, '0.1'), Token.new(:SEMI, ';'), Token.new(:RBRACE, '}')] =>
      Program.new([If.new(BinOp.new('>', Name.new('x'), FloatLiteral.new(0.1)), [Print.new(Name.new('x'))], [Print.new(FloatLiteral.new(0.1))])]),

    # for (var i = 0; i < 10; i = i + 1) { print i; }
    [Token.new(:FOR, 'for'), Token.new(:LPAREN, '('), Token.new(:VAR, 'var'), Token.new(:NAME, 'i'), Token.new(:ASSIGN, '='), Token.new(:INTEGER, '0'), Token.new(:SEMI, ';'), Token.new(:NAME, 'i'), Token.new(:LT, '<'), Token.new(:INTEGER, '10'), Token.new(:SEMI, ';'), Token.new(:NAME, 'i'), Token.new(:ASSIGN, '='), Token.new(:NAME, 'i'), Token.new(:PLUS, '+'), Token.new(:INTEGER, '1'), Token.new(:RPAREN, ')'), Token.new(:LBRACE, '{'), Token.new(:PRINT, 'print'), Token.new(:NAME, 'i'), Token.new(:SEMI, ';'), Token.new(:RBRACE, '}')] =>
      Program.new([ForLoop.new(VarDeclarationWithInit.new('i', IntegerLiteral.new(0)), BinOp.new('<', Name.new('i'), IntegerLiteral.new(10)), Assignment.new(Name.new('i'), BinOp.new('+', Name.new('i'), IntegerLiteral.new(1))), [Print.new(Name.new('i'))])]),

    # for (x = 5; x > 0; x = x - 1) { x = x * 2; }
    [Token.new(:FOR, 'for'), Token.new(:LPAREN, '('), Token.new(:NAME, 'x'), Token.new(:ASSIGN, '='), Token.new(:INTEGER, '5'), Token.new(:SEMI, ';'), Token.new(:NAME, 'x'), Token.new(:GT, '>'), Token.new(:INTEGER, '0'), Token.new(:SEMI, ';'), Token.new(:NAME, 'x'), Token.new(:ASSIGN, '='), Token.new(:NAME, 'x'), Token.new(:MINUS, '-'), Token.new(:INTEGER, '1'), Token.new(:RPAREN, ')'), Token.new(:LBRACE, '{'), Token.new(:NAME, 'x'), Token.new(:ASSIGN, '='), Token.new(:NAME, 'x'), Token.new(:TIMES, '*'), Token.new(:INTEGER, '2'), Token.new(:SEMI, ';'), Token.new(:RBRACE, '}')] =>
      Program.new([ForLoop.new(Assignment.new(Name.new('x'), IntegerLiteral.new(5)), BinOp.new('>', Name.new('x'), IntegerLiteral.new(0)), Assignment.new(Name.new('x'), BinOp.new('-', Name.new('x'), IntegerLiteral.new(1))), [Assignment.new(Name.new('x'), BinOp.new('*', Name.new('x'), IntegerLiteral.new(2)))])]),

    # Precedence: 2 + 3 * 4 should parse as 2 + (3 * 4)
    [Token.new(:PRINT, 'print'), Token.new(:INTEGER, '2'), Token.new(:PLUS, '+'), Token.new(:INTEGER, '3'), Token.new(:TIMES, '*'), Token.new(:INTEGER, '4'), Token.new(:SEMI, ';')] =>
      Program.new([Print.new(BinOp.new('+', IntegerLiteral.new(2), BinOp.new('*', IntegerLiteral.new(3), IntegerLiteral.new(4))))]),

    # Left-associativity: 10 - 3 - 2 should parse as (10 - 3) - 2
    [Token.new(:PRINT, 'print'), Token.new(:INTEGER, '10'), Token.new(:MINUS, '-'), Token.new(:INTEGER, '3'), Token.new(:MINUS, '-'), Token.new(:INTEGER, '2'), Token.new(:SEMI, ';')] =>
      Program.new([Print.new(BinOp.new('-', BinOp.new('-', IntegerLiteral.new(10), IntegerLiteral.new(3)), IntegerLiteral.new(2)))]),

    # Complex mixed precedence: 2 + 3 * 4 - 5 / 1 should parse as 2 + (3 * 4) - (5 / 1)
    [Token.new(:PRINT, 'print'), Token.new(:INTEGER, '2'), Token.new(:PLUS, '+'), Token.new(:INTEGER, '3'), Token.new(:TIMES, '*'), Token.new(:INTEGER, '4'), Token.new(:MINUS, '-'), Token.new(:INTEGER, '5'), Token.new(:DIVIDE, '/'), Token.new(:INTEGER, '1'), Token.new(:SEMI, ';')] =>
      Program.new([Print.new(BinOp.new('-', BinOp.new('+', IntegerLiteral.new(2), BinOp.new('*', IntegerLiteral.new(3), IntegerLiteral.new(4))), BinOp.new('/', IntegerLiteral.new(5), IntegerLiteral.new(1))))]),

  }

  generate_tests
end
