require_relative 'base'
require_relative '../compiler_error'
require_relative '../model'

module Walrus
  # Validates balanced braces and parentheses in token stream.
  # Uses stack-based algorithm to ensure proper nesting and matching.
  class BraceCheck < CompilerPass
    attr_accessor :source_lines
    OPENERS = [:LPAREN, :LBRACE].freeze
    CLOSERS = [:RPAREN, :RBRACE].freeze
    PAIRS = {
      RPAREN: :LPAREN,
      RBRACE: :LBRACE
    }.freeze

    def run(tokens)
      stack = []

      tokens.each do |token|
        if OPENERS.include?(token.toktype)
          stack.push(token)
        elsif CLOSERS.include?(token.toktype)
          check_closing_brace(token, stack)
        end
      end

      check_unclosed_braces(stack)
      tokens
    end

    private

    def check_closing_brace(token, stack)
      if stack.empty?
        loc = SourceLocation.new(token.lineno, token.column, @source_lines[token.lineno - 1]&.chomp, Walrus.context[:filename])
        raise CompilerError::SyntaxError.new(
          "Found '#{token.tokvalue}' with no opening brace",
          loc,
          hint: "Remove this '#{token.tokvalue}' or add a matching opening brace"
        )
      end

      opener = stack.pop
      expected = PAIRS[token.toktype]

      if opener.toktype != expected
        found_loc = SourceLocation.new(token.lineno, token.column, @source_lines[token.lineno - 1]&.chomp, Walrus.context[:filename])
        opener_loc = SourceLocation.new(opener.lineno, opener.column, @source_lines[opener.lineno - 1]&.chomp, Walrus.context[:filename])
        expected_close = closing_for(opener.toktype)
        raise CompilerError::SyntaxError.new(
          "Found '#{token.tokvalue}' but expected '#{expected_close}' to match '#{opener.tokvalue}' from line #{opener_loc.lineno}",
          found_loc,
          hint: "Change '#{token.tokvalue}' to '#{expected_close}' to match the opening brace"
        )
      end
    end

    def check_unclosed_braces(stack)
      return if stack.empty?

      opener = stack.first
      loc = SourceLocation.new(opener.lineno, opener.column, @source_lines[opener.lineno - 1]&.chomp, Walrus.context[:filename])
      closing = closing_for(opener.toktype)
      raise CompilerError::SyntaxError.new(
        "Found '#{opener.tokvalue}' with no closing brace",
        loc,
        hint: "Add '#{closing}' to close this block"
      )
    end

    def closing_for(opener_type)
      case opener_type
      when :LPAREN then ')'
      when :LBRACE then '}'
      end
    end
  end
end
