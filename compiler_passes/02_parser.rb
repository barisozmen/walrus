# parser.rb
#
# Recursive descent parser for the Walrus language. Converts a stream of tokens
# from the tokenizer into an Abstract Syntax Tree (AST) as defined in model.rb.
#
# The parser follows these design principles:
# 1. Predictive parsing - uses peek-ahead to determine which rule to apply
# 2. One method per grammar rule - clear mapping between grammar and code
# 3. Immutable AST construction - builds new nodes, never mutates existing ones
#
# Grammar overview:
#   program := statements
#   statements := statement*
#   statement := print_stmt | var_stmt | assign_stmt | if_stmt | while_stmt | func_stmt | return_stmt
#   expression := term ((PLUS | TIMES) term)?
#   term := INTEGER | NAME | LPAREN expression RPAREN | NAME LPAREN args RPAREN
#   relop := expression (EQ | LT) expression

require_relative '../model'
require_relative 'base'
require_relative '../compiler_error'


module Walrus
  # TokenStreamer module
  #
  # Encapsulates token stream navigation and management operations.
  # Provides methods for consuming tokens (expect), looking ahead (peek),
  # and checking stream status (at_end?).
  #
  # This module works with instance variables @tokens and @n which must be
  # provided by the including class.
  module TokenStreamer
    # Expect a specific token type and consume it, or raise an error
    # This is the fundamental operation for parsing
    def expect(toktype)
      tok = @tokens[@n]

      unless tok && tok.toktype == toktype
        loc = create_source_location(tok)

        hint = case toktype
               when :SEMI then "Add ';' at the end of the statement"
               when :RPAREN then "Add ')' to close the expression"
               when :RBRACE then "Add '}' to close the block"
               when :LPAREN then "Add '(' before the arguments"
               when :LBRACE then "Add '{' to start the block"
               else nil
               end

        raise CompilerError::SyntaxError.new(
          "Expected #{toktype}, got #{tok ? tok.toktype : 'EOF'}",
          loc,
          hint: hint
        )
      end

      @n += 1
      tok
    end

    # Peek at the current token type without consuming it
    # Used for predictive parsing decisions
    def peek(toktype)
      @n < @tokens.length && @tokens[@n].toktype == toktype
    end

    # simplifies the pattern of peek/except
    def accept(toktype)
      return false unless peek(toktype)
      expect(toktype)
    end

    def at_end?
      @n >= @tokens.length
    end
  end

  class Parser < CompilerPass
    include TokenStreamer

    def run(tokens, source: nil)
      @tokens = tokens
      @source_lines = source ? source.lines : []
      @n = 0  # Current position in token stream
      parse_program
    end

    # Attach source location to a node from a token
    def attach_location(node, tok)
      return node unless tok && @source_lines.any?
      node.loc = SourceLocation.new(
        tok.lineno,
        tok.column,
        @source_lines[tok.lineno - 1]&.chomp,
        Walrus.context[:filename]
      )
      node
    end

    # Create a SourceLocation from a token or current position
    def create_source_location(tok = nil)
      tok ||= @tokens[@n] || @tokens.last
      return nil unless tok

      SourceLocation.new(
        tok.lineno,
        tok.column,
        @source_lines[tok.lineno - 1]&.chomp,
        Walrus.context[:filename]
      )
    end

    def parse_program
      Program.new(parse_statements)
    end

    # Parse statements - loops until we hit RBRACE or EOF
    # Statements appear in { } blocks (if/while/function bodies) or at top level
    def parse_statements
      statements = []

      # Continue parsing statements until we hit a closing brace or end of file
      # RBRACE indicates end of a block { }
      # EOF indicates end of top-level program
      until peek(:RBRACE) || at_end?
        statements << parse_statement
      end

      statements
    end

    # ============================================================================
    # Step 5: Parse terms (values) and Step 6: Parse expressions with operators
    # ============================================================================

    # term := INTEGER | FLOAT | NAME | LPAREN expression RPAREN | NAME LPAREN args RPAREN | MINUS term
    def parse_term
      if peek(:INTEGER)
        tok = expect(:INTEGER)
        attach_location(IntegerLiteral.new(tok.tokvalue.to_i), tok)

      elsif peek(:FLOAT)
        tok = expect(:FLOAT)
        attach_location(FloatLiteral.new(tok.tokvalue.to_f), tok)

      elsif peek(:CHARACTER)
        tok = expect(:CHARACTER)
        attach_location(CharacterLiteral.new(tok.tokvalue), tok)

      elsif peek(:STRING)
        tok = expect(:STRING)
        attach_location(StringLiteral.new(tok.tokvalue), tok)

      elsif peek(:NAME)
        # Could be a variable name or function call
        nametok = expect(:NAME)
        name = nametok.tokvalue

        if peek(:LPAREN)
          # Function call: name(arg1, arg2, ...)
          expect(:LPAREN)

          # Parse arguments (comma-separated expressions)
          args = []
          unless peek(:RPAREN)  # Check if we have any arguments
            args << parse_expression
            while peek(:COMMA)
              expect(:COMMA)
              args << parse_expression
            end
          end

          expect(:RPAREN)
          attach_location(Call.new(name, args), nametok)
        else
          # Just a variable name
          attach_location(Name.new(name), nametok)
        end

      elsif peek(:LPAREN)
        # Parenthesized expression: (expr)
        expect(:LPAREN)
        expr = parse_expression
        expect(:RPAREN)
        expr

      elsif peek(:MINUS)
        # Unary negation: -term
        expect(:MINUS)
        operand = parse_term
        UnaryOp.new('-', operand)

      elsif peek(:GETS)
        # User input: gets
        tok = expect(:GETS)
        attach_location(Gets.new, tok)

      else
        tok = @tokens[@n]
        loc = create_source_location(tok)
        raise CompilerError::SyntaxError.new("Expected a term, got #{tok ? tok.toktype : 'EOF'}", loc)
      end
    end

    # expression := mulop ((PLUS | MINUS) mulop)*
    # mulop := term ((TIMES | DIVIDE) term)*
    def parse_expression
      left = parse_mulop

      loop do
        if tok = accept(:PLUS)
          right = parse_mulop
          left = attach_location(BinOp.new('+', left, right), tok)
        elsif tok = accept(:MINUS)
          right = parse_mulop
          left = attach_location(BinOp.new('-', left, right), tok)
        else
          return left
        end
      end
    end

    # mulop := term ((TIMES | DIVIDE) term)*
    def parse_mulop
      left = parse_term

      loop do
        if tok = accept(:TIMES)
          right = parse_term
          left = attach_location(BinOp.new('*', left, right), tok)
        elsif tok = accept(:DIVIDE)
          right = parse_term
          left = attach_location(BinOp.new('/', left, right), tok)
        else
          return left
        end
      end
    end

    # Parse logical operators - handles 'and', 'or'
    # logical := relop ((AND | OR) relop)*
    def parse_logical
      left = parse_relop

      if tok = accept(:AND)
        right = parse_logical
        attach_location(BinOp.new('and', left, right), tok)
      elsif tok = accept(:OR)
        right = parse_logical
        attach_location(BinOp.new('or', left, right), tok)
      else
        left
      end
    end

    # Parse relational operator - handles <, <=, >, >=, ==, !=
    # relop := expression (LT | LE | GT | GE | EQ | NE) expression
    def parse_relop
      left = parse_expression

      # Check for common error: assignment operator instead of comparison
      if peek(:ASSIGN)
        tok = @tokens[@n]
        loc = SourceLocation.new(tok.lineno, tok.column, @source_lines[tok.lineno - 1]&.chomp, Walrus.context[:filename])
        raise CompilerError::SyntaxError.new(
          "Invalid syntax. Did you mean '==' instead of '='?",
          loc,
          hint: "Use '==' for comparison, '=' is for assignment"
        )
      end

      if tok = accept(:LT)
        right = parse_expression
        attach_location(BinOp.new('<', left, right), tok)
      elsif tok = accept(:LE)
        right = parse_expression
        attach_location(BinOp.new('<=', left, right), tok)
      elsif tok = accept(:GT)
        right = parse_expression
        attach_location(BinOp.new('>', left, right), tok)
      elsif tok = accept(:GE)
        right = parse_expression
        attach_location(BinOp.new('>=', left, right), tok)
      elsif tok = accept(:EQ)
        right = parse_expression
        attach_location(BinOp.new('==', left, right), tok)
      elsif tok = accept(:NE)
        right = parse_expression
        attach_location(BinOp.new('!=', left, right), tok)
      else
        left
      end
    end

    # ============================================================================
    # Step 2: Statement Parsing Methods
    # Each method parses a specific statement type according to Walrus grammar
    # ============================================================================

    # Parse print statement: print expression ;
    def parse_print
      expect(:PRINT)
      value = parse_logical
      expect(:SEMI)
      Print.new(value)

    end

    # Parse type specifier: int | float | bool | char | str
    def parse_type_spec
      if accept(:INT)
        'int'
      elsif accept(:FLOAT)
        'float'
      elsif accept(:BOOL)
        'bool'
      elsif accept(:CHAR)
        'char'
      elsif accept(:STR)
        'str'
      else
        tok = @tokens[@n]
        loc = create_source_location(tok)
        raise CompilerError::SyntaxError.new(
          "Expected type specifier (int, float, bool, char, str), got #{tok ? tok.toktype : 'EOF'}",
          loc,
          hint: "Add type annotation (e.g., 'int') or initializer (e.g., '= 0')"
        )
      end
    end

    # Parse variable declaration: var name [type] [= expression] [;]
    # Examples:
    #   var x int;           -> VarDeclarationWithoutInit with type_spec
    #   var x int = 10;      -> VarDeclarationWithInit with type_spec
    #   var x = 10;          -> VarDeclarationWithInit without type_spec (inferred)
    def parse_variable(expect_semi: true)
      expect(:VAR)
      nametok = expect(:NAME)
      name = nametok.tokvalue

      # Look ahead: is there a type specifier?
      if peek(:INT) || peek(:FLOAT) || peek(:BOOL) || peek(:CHAR) || peek(:STR)
        type = parse_type_spec

        # var x int = 10; or var x int;
        if accept(:ASSIGN)
          value = parse_expression
          expect(:SEMI) if expect_semi
          decl = VarDeclarationWithInit.new(name, value)
          decl.type = type
          decl
        else
          expect(:SEMI) if expect_semi
          decl = VarDeclarationWithoutInit.new(name)
          decl.type = type
          decl
        end
      elsif accept(:ASSIGN)
        # var x = 10; (inferred type)
        value = parse_expression
        expect(:SEMI) if expect_semi
        VarDeclarationWithInit.new(name, value)
      else
        tok = @tokens[@n]
        loc = create_source_location(tok)
        raise CompilerError::SyntaxError.new(
          "Variable declaration requires type or initializer",
          loc,
          hint: "Add type annotation (e.g., 'int') or initializer (e.g., '= 0')"
        )
      end
    end

    # Parse assignment statement: name = expression [;]
    def parse_assignment(expect_semi: true)
      nametok = expect(:NAME)
      name = nametok.tokvalue
      tok = expect(:ASSIGN)
      value = parse_expression
      expect(:SEMI) if expect_semi
      attach_location(Assignment.new(Name.new(name), value), tok)
    end

    # Parse expression statement: expression ;
    # Expression is evaluated but result is discarded
    def parse_expr_statement
      expr = parse_expression
      expect(:SEMI)
      ExprStatement.new(expr)
    end

    # Parse if statement: if relop { statements } [else { statements }]
    def parse_if
      start_pos = @n
      expect(:IF)
      condition = parse_logical
      expect(:LBRACE)
      then_block = parse_statements
      expect(:RBRACE)

      # Check if elsif follows - if so, rewind and parse as ElsIf
      if peek(:ELSIF)
        @n = start_pos
        return parse_elsif
      end

      # else clause is now optional
      if accept(:ELSE)
        expect(:LBRACE)
        else_block = parse_statements
        expect(:RBRACE)
      else
        else_block = []
      end

      If.new(condition, then_block, else_block)
    end

    # Parse elsif statement: if cond { block } elsif cond { block } ... [else { block }]
    def parse_elsif
      expect(:IF)
      condition = parse_logical
      expect(:LBRACE)
      then_block = parse_statements
      expect(:RBRACE)

      elsif_branches = []
      while accept(:ELSIF)
        elsif_condition = parse_logical
        expect(:LBRACE)
        elsif_then_block = parse_statements
        expect(:RBRACE)
        elsif_branches << ElsIfBranch.new(elsif_condition, elsif_then_block)
      end

      # else clause is optional
      if accept(:ELSE)
        expect(:LBRACE)
        else_block = parse_statements
        expect(:RBRACE)
      else
        else_block = []
      end

      ElsIf.new(condition, then_block, elsif_branches, else_block)
    end

    # Parse case statement: case expr { when expr { block } ... [else { block }] }
    def parse_case
      expect(:CASE)
      test_expr = parse_expression
      expect(:LBRACE)

      when_branches = []
      while accept(:WHEN)
        match_expr = parse_expression
        expect(:LBRACE)
        when_block = parse_statements
        expect(:RBRACE)
        when_branches << WhenBranch.new(match_expr, when_block)
      end

      # else clause is optional
      if accept(:ELSE)
        expect(:LBRACE)
        else_block = parse_statements
        expect(:RBRACE)
      else
        else_block = []
      end

      expect(:RBRACE)
      Case.new(test_expr, when_branches, else_block)
    end

    # while relop { statements }
    def parse_while
      expect(:WHILE)
      condition = parse_logical
      expect(:LBRACE)
      body = parse_statements
      expect(:RBRACE)
      While.new(condition, body)
    end

    # for (init; condition; update) { statements }
    def parse_for
      expect(:FOR)
      expect(:LPAREN)

      # Parse init (var declaration or assignment, or nil)
      init = if peek(:VAR)
        parse_variable(expect_semi: false)
      elsif peek(:NAME)
        parse_assignment(expect_semi: false)
      else
        nil
      end

      expect(:SEMI)
      condition = parse_logical
      expect(:SEMI)

      # Parse update (assignment without semicolon, or nil)
      update = if peek(:NAME)
        parse_assignment(expect_semi: false)
      else
        nil
      end

      expect(:RPAREN)
      expect(:LBRACE)
      body = parse_statements
      expect(:RBRACE)

      ForLoop.new(init, condition, update, body)
    end

    # Parse function parameters: name type [, name type]*
    def parse_function_parameters
      params = []
      return params if peek(:RPAREN)

      loop do
        param_name = expect(:NAME).tokvalue
        param_type = parse_type_spec
        param = Parameter.new(param_name)
        param.type = param_type
        params << param
        break unless accept(:COMMA)
      end

      params
    end

    # func name(param1 type1, param2 type2, ...) return_type { statements }
    # Example: func add(x int, y int) int { ... }
    def parse_function
      expect(:FUNC)
      nametok = expect(:NAME)
      name = nametok.tokvalue
      expect(:LPAREN)
      params = parse_function_parameters
      expect(:RPAREN)

      # Parse optional return type
      if peek(:INT) || peek(:FLOAT) || peek(:BOOL) || peek(:CHAR) || peek(:STR)
        return_type = parse_type_spec
      else
        return_type = nil  # Infer later
      end

      expect(:LBRACE)
      body = parse_statements
      expect(:RBRACE)

      Function.new(name, params, body, type: return_type)
    end

    # return expression ;
    def parse_return
      return_tok = expect(:RETURN)
      value = parse_expression
      expect(:SEMI)
      attach_location(Return.new(value), return_tok)
    end

    # break ;
    def parse_break
      break_tok = expect(:BREAK)
      expect(:SEMI)
      attach_location(Break.new, break_tok)
    end

    # continue ;
    def parse_continue
      continue_tok = expect(:CONTINUE)
      expect(:SEMI)
      attach_location(Continue.new, continue_tok)
    end

    # ============================================================================
    # Step 3: Generic Statement Parsing
    # Parse any valid Walrus statement using predictive parsing (peek-ahead)
    # ============================================================================

    def parse_statement
      # Use predictive parsing - peek at the current token to decide which
      # parsing method to call. This is more efficient than backtracking.
      if peek(:PRINT)
        parse_print
      elsif peek(:VAR)
        parse_variable
      elsif peek(:IF)
        parse_if
      elsif peek(:CASE)
        parse_case
      elsif peek(:WHILE)
        parse_while
      elsif peek(:FOR)
        parse_for
      elsif peek(:FUNC)
        parse_function
      elsif peek(:RETURN)
        parse_return
      elsif peek(:BREAK)
        parse_break
      elsif peek(:CONTINUE)
        parse_continue
      elsif peek(:NAME)
        # Ambiguity: NAME could be assignment (x = y;) or expr statement (f(x);)
        # Peek ahead to distinguish
        parse_name_statement
      elsif peek(:INTEGER) || peek(:LPAREN) || peek(:MINUS)
        # Expression statement: INTEGER, LPAREN, MINUS can start expressions
        parse_expr_statement
      else
        tok = @tokens[@n]
        loc = create_source_location(tok)
        raise CompilerError::SyntaxError.new(
          "Expected a statement, got #{tok ? tok.toktype : 'EOF'}",
          loc,
          hint: "Add a statement (e.g., 'print 42;') or correct the syntax"
        )
      end
    end

    # Resolve NAME ambiguity: assignment vs expression statement
    def parse_name_statement
      # Look ahead: is it NAME ASSIGN or NAME something_else?
      if @n + 1 < @tokens.length && @tokens[@n + 1].toktype == :ASSIGN
        parse_assignment
      else
        parse_expr_statement
      end
    end
  end
end
