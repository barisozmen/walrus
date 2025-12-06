require_relative '../test_context'

class BraceCheckTest < Minitest::Test
  auto_test do |tokens, expected|
    checker = Walrus::BraceCheck.new
    checker.source_lines = []  # Set empty source lines for tests

    if expected == :error
      assert_raises(CompilerError::SyntaxError) { checker.run(tokens) }
    else
      result = checker.run(tokens)
      assert_equal expected, result
    end
  end

  TESTCASES = {
    # Valid cases - pass through unchanged

    [] =>
      [],

    [Token.new(:LPAREN, '(', 1), Token.new(:INTEGER, '42', 1), Token.new(:RPAREN, ')', 1)] =>
      [Token.new(:LPAREN, '(', 1), Token.new(:INTEGER, '42', 1), Token.new(:RPAREN, ')', 1)],

    [Token.new(:LBRACE, '{', 1), Token.new(:PRINT, 'print', 1), Token.new(:INTEGER, '42', 1), Token.new(:SEMI, ';', 1), Token.new(:RBRACE, '}', 1)] =>
      [Token.new(:LBRACE, '{', 1), Token.new(:PRINT, 'print', 1), Token.new(:INTEGER, '42', 1), Token.new(:SEMI, ';', 1), Token.new(:RBRACE, '}', 1)],

    [Token.new(:LBRACE, '{', 1), Token.new(:LPAREN, '(', 2), Token.new(:INTEGER, '1', 2), Token.new(:RPAREN, ')', 2), Token.new(:RBRACE, '}', 3)] =>
      [Token.new(:LBRACE, '{', 1), Token.new(:LPAREN, '(', 2), Token.new(:INTEGER, '1', 2), Token.new(:RPAREN, ')', 2), Token.new(:RBRACE, '}', 3)],

    [Token.new(:LPAREN, '(', 1), Token.new(:RPAREN, ')', 1), Token.new(:LBRACE, '{', 2), Token.new(:RBRACE, '}', 2)] =>
      [Token.new(:LPAREN, '(', 1), Token.new(:RPAREN, ')', 1), Token.new(:LBRACE, '{', 2), Token.new(:RBRACE, '}', 2)],

    [Token.new(:LBRACE, '{', 1), Token.new(:LBRACE, '{', 2), Token.new(:LPAREN, '(', 3), Token.new(:LPAREN, '(', 3), Token.new(:RPAREN, ')', 3), Token.new(:RPAREN, ')', 3), Token.new(:RBRACE, '}', 4), Token.new(:RBRACE, '}', 5)] =>
      [Token.new(:LBRACE, '{', 1), Token.new(:LBRACE, '{', 2), Token.new(:LPAREN, '(', 3), Token.new(:LPAREN, '(', 3), Token.new(:RPAREN, ')', 3), Token.new(:RPAREN, ')', 3), Token.new(:RBRACE, '}', 4), Token.new(:RBRACE, '}', 5)],

    # func f(x) { if x > 0 { print x; } }
    [Token.new(:FUNC, 'func', 1), Token.new(:NAME, 'f', 1), Token.new(:LPAREN, '(', 1), Token.new(:NAME, 'x', 1), Token.new(:RPAREN, ')', 1), Token.new(:LBRACE, '{', 1), Token.new(:IF, 'if', 2), Token.new(:NAME, 'x', 2), Token.new(:GT, '>', 2), Token.new(:INTEGER, '0', 2), Token.new(:LBRACE, '{', 2), Token.new(:PRINT, 'print', 3), Token.new(:NAME, 'x', 3), Token.new(:SEMI, ';', 3), Token.new(:RBRACE, '}', 4), Token.new(:RBRACE, '}', 5)] =>
      [Token.new(:FUNC, 'func', 1), Token.new(:NAME, 'f', 1), Token.new(:LPAREN, '(', 1), Token.new(:NAME, 'x', 1), Token.new(:RPAREN, ')', 1), Token.new(:LBRACE, '{', 1), Token.new(:IF, 'if', 2), Token.new(:NAME, 'x', 2), Token.new(:GT, '>', 2), Token.new(:INTEGER, '0', 2), Token.new(:LBRACE, '{', 2), Token.new(:PRINT, 'print', 3), Token.new(:NAME, 'x', 3), Token.new(:SEMI, ';', 3), Token.new(:RBRACE, '}', 4), Token.new(:RBRACE, '}', 5)],

    # Error cases - extra closing brace

    [Token.new(:LBRACE, '{', 1), Token.new(:RBRACE, '}', 2), Token.new(:RBRACE, '}', 3)] =>
      :error,

    [Token.new(:LPAREN, '(', 1), Token.new(:RPAREN, ')', 1), Token.new(:RPAREN, ')', 2)] =>
      :error,

    # Error cases - missing closing brace

    [Token.new(:LBRACE, '{', 1), Token.new(:PRINT, 'print', 2), Token.new(:INTEGER, '42', 2), Token.new(:SEMI, ';', 2)] =>
      :error,

    [Token.new(:LPAREN, '(', 5), Token.new(:INTEGER, '10', 5), Token.new(:PLUS, '+', 5), Token.new(:INTEGER, '20', 5)] =>
      :error,

    # Error cases - wrong closing brace type

    [Token.new(:LBRACE, '{', 1), Token.new(:RPAREN, ')', 2)] =>
      :error,

    [Token.new(:LPAREN, '(', 1), Token.new(:RBRACE, '}', 2)] =>
      :error
  }

  generate_tests
end
