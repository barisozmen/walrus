require_relative '../test_context'

class TokenizerTest < Minitest::Test
  auto_test do |source, expected|
    result = Walrus::Tokenizer.new.run(source)
    assert_equal expected, result
  end

  TESTCASES = {
    # Empty and whitespace
    "" => [],
    "   \n\t  " => [],

    # Integers
    "123" => [Token.new(:INTEGER, '123')],
    "10 20 30" => [Token.new(:INTEGER, '10'), Token.new(:INTEGER, '20'), Token.new(:INTEGER, '30')],

    # Operators
    "+ *" => [Token.new(:PLUS, '+'), Token.new(:TIMES, '*')],
    "< ==" => [Token.new(:LT, '<'), Token.new(:EQ, '==')],
    "= ==" => [Token.new(:ASSIGN, '='), Token.new(:EQ, '==')],

    # Punctuation
    "; ( ) { } ," => [Token.new(:SEMI, ';'), Token.new(:LPAREN, '('), Token.new(:RPAREN, ')'), Token.new(:LBRACE, '{'), Token.new(:RBRACE, '}'), Token.new(:COMMA, ',')],

    # Keywords
    "var" => [Token.new(:VAR, 'var')],
    "print" => [Token.new(:PRINT, 'print')],
    "if else while" => [Token.new(:IF, 'if'), Token.new(:ELSE, 'else'), Token.new(:WHILE, 'while')],
    "func return" => [Token.new(:FUNC, 'func'), Token.new(:RETURN, 'return')],

    # Identifiers
    "abc" => [Token.new(:NAME, 'abc')],
    "abc123" => [Token.new(:NAME, 'abc123')],
    "myVar123" => [Token.new(:NAME, 'myVar123')],
    "if if2 ifx varx" => [Token.new(:IF, 'if'), Token.new(:NAME, 'if2'), Token.new(:NAME, 'ifx'), Token.new(:NAME, 'varx')],

    # Comments
    "// comment" => [],
    "123 // comment" => [Token.new(:INTEGER, '123')],
    "123 // comment\n456" => [Token.new(:INTEGER, '123'), Token.new(:INTEGER, '456')],

    # Expressions
    "10 + 20" => [Token.new(:INTEGER, '10'), Token.new(:PLUS, '+'), Token.new(:INTEGER, '20')],
    "(10 + 20) * 30" => [Token.new(:LPAREN, '('), Token.new(:INTEGER, '10'), Token.new(:PLUS, '+'), Token.new(:INTEGER, '20'), Token.new(:RPAREN, ')'), Token.new(:TIMES, '*'), Token.new(:INTEGER, '30')],
    "x < 10" => [Token.new(:NAME, 'x'), Token.new(:LT, '<'), Token.new(:INTEGER, '10')],
    "x == 42" => [Token.new(:NAME, 'x'), Token.new(:EQ, '=='), Token.new(:INTEGER, '42')],

    # Statements
    "var x = 10;" => [Token.new(:VAR, 'var'), Token.new(:NAME, 'x'), Token.new(:ASSIGN, '='), Token.new(:INTEGER, '10'), Token.new(:SEMI, ';')],
    "x = x + 1;" => [Token.new(:NAME, 'x'), Token.new(:ASSIGN, '='), Token.new(:NAME, 'x'), Token.new(:PLUS, '+'), Token.new(:INTEGER, '1'), Token.new(:SEMI, ';')],
    "print x;" => [Token.new(:PRINT, 'print'), Token.new(:NAME, 'x'), Token.new(:SEMI, ';')],
    "if x < y {" => [Token.new(:IF, 'if'), Token.new(:NAME, 'x'), Token.new(:LT, '<'), Token.new(:NAME, 'y'), Token.new(:LBRACE, '{')],
    "while x < 10 {" => [Token.new(:WHILE, 'while'), Token.new(:NAME, 'x'), Token.new(:LT, '<'), Token.new(:INTEGER, '10'), Token.new(:LBRACE, '{')],
    "func add(x, y) {" => [Token.new(:FUNC, 'func'), Token.new(:NAME, 'add'), Token.new(:LPAREN, '('), Token.new(:NAME, 'x'), Token.new(:COMMA, ','), Token.new(:NAME, 'y'), Token.new(:RPAREN, ')'), Token.new(:LBRACE, '{')],
    "return x;" => [Token.new(:RETURN, 'return'), Token.new(:NAME, 'x'), Token.new(:SEMI, ';')],

    # Edge cases
    "var x=10;" => [Token.new(:VAR, 'var'), Token.new(:NAME, 'x'), Token.new(:ASSIGN, '='), Token.new(:INTEGER, '10'), Token.new(:SEMI, ';')],
    "x === y" => [Token.new(:NAME, 'x'), Token.new(:EQ, '=='), Token.new(:ASSIGN, '='), Token.new(:NAME, 'y')],
    "x+y*z" => [Token.new(:NAME, 'x'), Token.new(:PLUS, '+'), Token.new(:NAME, 'y'), Token.new(:TIMES, '*'), Token.new(:NAME, 'z')],
    "print 123 + xy;" => [Token.new(:PRINT, 'print'), Token.new(:INTEGER, '123'), Token.new(:PLUS, '+'), Token.new(:NAME, 'xy'), Token.new(:SEMI, ';')],

    # Floats
    "123.45" => [Token.new(:FLOAT, '123.45')],
    "123.45 + 67.89" => [Token.new(:FLOAT, '123.45'), Token.new(:PLUS, '+'), Token.new(:FLOAT, '67.89')],
    "print 123.45 + xy;" => [Token.new(:PRINT, 'print'), Token.new(:FLOAT, '123.45'), Token.new(:PLUS, '+'), Token.new(:NAME, 'xy'), Token.new(:SEMI, ';')]
  }

  generate_tests
end
