require_relative 'base'
require_relative '../compiler_error'

Token = Struct.new(:toktype, :tokvalue, :lineno, :column) do
  def to_s
    "Token(#{toktype}, #{tokvalue.inspect}, line=#{lineno}, col=#{column})"
  end

  def ==(other)
    other.is_a?(Token) && toktype == other.toktype && tokvalue == other.tokvalue
  end
end

RESERVED_KEYWORDS = {
  'var' => :VAR,
  'print' => :PRINT,
  'gets' => :GETS,
  'if' => :IF,
  'else' => :ELSE,
  'elsif' => :ELSIF,
  'case' => :CASE,
  'when' => :WHEN,
  'while' => :WHILE,
  'for' => :FOR,
  'func' => :FUNC,
  'return' => :RETURN,
  'break' => :BREAK,
  'continue' => :CONTINUE,
  'int' => :INT,
  'float' => :FLOAT,
  'bool' => :BOOL,
  'char' => :CHAR,
  'str' => :STR,
  'and' => :AND,
  'or' => :OR
}.freeze

OPERATORS = {
  '+' => :PLUS,
  '-' => :MINUS,
  '*' => :TIMES,
  '/' => :DIVIDE,
  '<=' => :LE,
  '>=' => :GE,
  '<' => :LT,
  '>' => :GT,
  '==' => :EQ,
  '!=' => :NE,
  '=' => :ASSIGN
}.freeze

SYMBOLS = {
  ';' => :SEMI,
  '(' => :LPAREN,
  ')' => :RPAREN,
  '{' => :LBRACE,
  '}' => :RBRACE,
  ',' => :COMMA
}.freeze

COMMENT_START = '//'

module Walrus
  class Tokenizer < CompilerPass
    def run(text)
      @text = text
      @tokens = []
      @n = 0
      @lineno = 1
      @column = 1
      scan
      @tokens
    end

    private

    def scan
      while @n < @text.length
        next if skip_whitespace
        next if skip_comment
        next if scan_float
        next if scan_integer
        next if scan_character
        next if scan_string
        next if scan_name
        next if scan_operator
        next if scan_symbol

        loc = SourceLocation.new(@lineno, @column, extract_source_line(@lineno), nil)
        raise CompilerError::SyntaxError.new("Unexpected character '#{@text[@n]}'", loc)
      end
    end

    def skip_whitespace
      return false unless @text[@n].match?(/\s/)
      if @text[@n] == "\n"
        @lineno += 1
        @column = 1
      else
        @column += 1
      end
      @n += 1
      true
    end

    def skip_comment
      return false unless @n < @text.length - 1 && @text[@n..@n + 1] == COMMENT_START
      while @n < @text.length && @text[@n] != "\n"
        @n += 1
        @column += 1
      end
      if @n < @text.length
        @lineno += 1
        @column = 1
        @n += 1
      end
      true
    end

    def scan_float
      return false unless @text[@n].match?(/\d/)
      start = @n
      start_col = @column
      @n += 1
      @column += 1
      while @n < @text.length && @text[@n].match?(/\d/)
        @n += 1
        @column += 1
      end

      # Check for decimal point
      if @n < @text.length && @text[@n] == '.'
        @n += 1
        @column += 1
        # Must have at least one digit after decimal
        return false unless @n < @text.length && @text[@n].match?(/\d/)
        while @n < @text.length && @text[@n].match?(/\d/)
          @n += 1
          @column += 1
        end
        @tokens << Token.new(:FLOAT, @text[start...@n], @lineno, start_col)
        return true
      end

      # No decimal point, reset and let scan_integer handle it
      @n = start
      @column = start_col
      false
    end

    def scan_integer
      return false unless @text[@n].match?(/\d/)
      start = @n
      start_col = @column
      while @n < @text.length && @text[@n].match?(/\d/)
        @n += 1
        @column += 1
      end
      @tokens << Token.new(:INTEGER, @text[start...@n], @lineno, start_col)
      true
    end

    def scan_character
      return false unless @text[@n] == "'"
      start_col = @column
      @n += 1
      @column += 1

      if @n >= @text.length
        loc = SourceLocation.new(@lineno, start_col, extract_source_line(@lineno), nil)
        raise CompilerError::SyntaxError.new("Unterminated character literal", loc)
      end

      # Handle escape sequences
      if @text[@n] == '\\'
        @n += 1
        @column += 1

        if @n >= @text.length
          loc = SourceLocation.new(@lineno, start_col, extract_source_line(@lineno), nil)
          raise CompilerError::SyntaxError.new("Unterminated escape sequence", loc)
        end

        char = case @text[@n]
               when 'n' then "\n"
               when 't' then "\t"
               when '\\' then "\\"
               when "'" then "'"
               when '0' then "\0"
               else
                 loc = SourceLocation.new(@lineno, @column, extract_source_line(@lineno), nil)
                 raise CompilerError::SyntaxError.new("Unknown escape sequence: \\#{@text[@n]}", loc)
               end
        @n += 1
        @column += 1
      else
        # Regular character
        char = @text[@n]
        @n += 1
        @column += 1
      end

      # Expect closing '
      unless @n < @text.length && @text[@n] == "'"
        loc = SourceLocation.new(@lineno, start_col, extract_source_line(@lineno), nil)
        raise CompilerError::SyntaxError.new("Unterminated character literal (missing closing ')", loc)
      end

      @n += 1
      @column += 1

      @tokens << Token.new(:CHARACTER, char, @lineno, start_col)
      true
    end

    def scan_string
      return false unless @text[@n] == '"'
      start_col = @column
      @n += 1
      @column += 1

      str = ""
      while @n < @text.length && @text[@n] != '"'
        if @text[@n] == '\\'
          @n += 1
          @column += 1

          if @n >= @text.length
            loc = SourceLocation.new(@lineno, start_col, extract_source_line(@lineno), nil)
            raise CompilerError::SyntaxError.new("Unterminated string literal", loc)
          end

          # Handle escape sequences
          str << case @text[@n]
                 when 'n' then "\n"
                 when 't' then "\t"
                 when '\\' then "\\"
                 when '"' then '"'
                 when '0' then "\0"
                 else
                   loc = SourceLocation.new(@lineno, @column, extract_source_line(@lineno), nil)
                   raise CompilerError::SyntaxError.new("Unknown escape sequence: \\#{@text[@n]}", loc)
                 end
          @n += 1
          @column += 1
        elsif @text[@n] == "\n"
          loc = SourceLocation.new(@lineno, start_col, extract_source_line(@lineno), nil)
          raise CompilerError::SyntaxError.new("Unterminated string literal (newline in string)", loc)
        else
          str << @text[@n]
          @n += 1
          @column += 1
        end
      end

      unless @n < @text.length && @text[@n] == '"'
        loc = SourceLocation.new(@lineno, start_col, extract_source_line(@lineno), nil)
        raise CompilerError::SyntaxError.new("Unterminated string literal (missing closing \")", loc)
      end

      @n += 1
      @column += 1

      @tokens << Token.new(:STRING, str, @lineno, start_col)
      true
    end

    def scan_name
      return false unless @text[@n].match?(/[a-zA-Z_]/)
      start = @n
      start_col = @column
      while @n < @text.length && @text[@n].match?(/[a-zA-Z0-9_]/)
        @n += 1
        @column += 1
      end
      name = @text[start...@n]

      if RESERVED_KEYWORDS.key?(name)
        @tokens << Token.new(RESERVED_KEYWORDS[name], name, @lineno, start_col)
      else
        @tokens << Token.new(:NAME, name, @lineno, start_col)
      end
      true
    end

    def scan_operator
      start_col = @column
      if @n < @text.length - 1
        two_char = @text[@n..@n + 1]
        if OPERATORS.key?(two_char)
          @tokens << Token.new(OPERATORS[two_char], two_char, @lineno, start_col)
          @n += 2
          @column += 2
          return true
        end
      end

      return false unless OPERATORS.key?(@text[@n])
      @tokens << Token.new(OPERATORS[@text[@n]], @text[@n], @lineno, start_col)
      @n += 1
      @column += 1
      true
    end

    def scan_symbol
      return false unless SYMBOLS.key?(@text[@n])
      @tokens << Token.new(SYMBOLS[@text[@n]], @text[@n], @lineno, @column)
      @n += 1
      @column += 1
      true
    end

    def extract_source_line(lineno)
      @text.lines[lineno - 1]&.chomp
    end
  end
end
