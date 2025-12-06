# format.rb
#
# Code formatter for the Walrus language.
# Transforms AST nodes back into nicely formatted source code.
#
# Uses dynamic dispatch (metaprogramming) for handling different node types.

require_relative 'model'
require_relative 'precedence'

class Formatter
  include Precedence

  def initialize(indent_size: 4)
    @indent_size = indent_size
    @indent_level = 0
  end

  # Main entry point: format a complete program
  def format_program(program)
    raise ArgumentError, "Expected Program, got #{program.class}" unless program.is_a?(Program)
    format_statements(program.statements)
  end

  def format_statements(statements)
    statements.map { |stmt| format_statement(stmt) }.join
  end

  # uses dynamic dispatch
  def format_statement(stmt)
    return format_statement_node(stmt) if stmt.is_a?(STATEMENT)
    dynamic_format(stmt)
  end

  # uses dynamic dispatch
  def format_expression(expr)
    dynamic_format(expr)
  end

  private

  def var_decl(keyword, name, value = nil)
    if value
      indent + "#{keyword} #{name} = #{format_expression(value)};\n"
    else
      indent + "#{keyword} #{name};\n"
    end
  end

  # Extract Method: Consolidates duplicate dynamic dispatch pattern
  # Used by format_statement, format_expression, and format_instruction
  def dynamic_format(node, suffix: '', error_prefix: '')
    method_name = "format_#{node.class.name.downcase}#{suffix}"
    unless respond_to?(method_name, true)
      raise "Cannot format #{error_prefix}#{node.class.name}"
    end
    send(method_name, node)
  end

  # ========================================================================
  # Statement formatters
  # ========================================================================

  def format_vardeclarationwithinit(stmt)
    var_decl("var", stmt.name, stmt.value)
  end

  def format_vardeclarationwithoutinit(stmt)
    var_decl("var", stmt.name)
  end

  def format_globalvardeclarationwithoutinit(stmt)
    var_decl("global", stmt.name)
  end

  def format_localvardeclarationwithoutinit(stmt)
    var_decl("local", stmt.name)
  end

  def format_globalvardeclarationwithinit(stmt)
    var_decl("global", stmt.name, stmt.value)
  end

  def format_localvardeclarationwithinit(stmt)
    var_decl("local", stmt.name, stmt.value)
  end

  # Legacy aliases for backward compatibility
  def format_globalvar(stmt)
    indent + "global #{stmt.name};\n"
  end

  def format_localvar(stmt)
    indent + "local #{stmt.name};\n"
  end

  def format_assignment(stmt)
    indent + "#{format_expression(stmt.name_ref)} = #{format_expression(stmt.value)};\n"
  end

  def format_print(stmt)
    indent + "print #{format_expression(stmt.value)};\n"
  end

  def format_if(stmt)
    result = indent + "if #{format_expression(stmt.condition)} {\n"

    # Format then block
    increase_indent do
      result += format_statements(stmt.then_block)
    end

    result += indent + "}"

    # Format else block if present
    if stmt.else_block && !stmt.else_block.empty?
      result += " else {\n"
      increase_indent do
        result += format_statements(stmt.else_block)
      end
      result += indent + "}"
    end

    result += "\n"
    result
  end

  def format_while(stmt)
    result = indent + "while #{format_expression(stmt.condition)} {\n"

    increase_indent do
      result += format_statements(stmt.body)
    end

    result += indent + "}\n"
    result
  end

  def format_forloop(stmt)
    init_str = stmt.init ? format_statement(stmt.init).strip.sub(/;$/, '') : ""
    update_str = stmt.update ? format_statement(stmt.update).strip.sub(/;$/, '') : ""

    result = indent + "for (#{init_str}; #{format_expression(stmt.condition)}; #{update_str}) {\n"

    increase_indent do
      result += format_statements(stmt.body)
    end

    result += indent + "}\n"
    result
  end

  def format_function(stmt)
    params = stmt.params.join(', ')
    result = indent + "func #{stmt.name}(#{params}) {\n"

    increase_indent do
      result += format_statements(stmt.body)
    end

    result += indent + "}\n"
    result
  end

  def format_return(stmt)
    indent + "return #{format_expression(stmt.value)};\n"
  end

  # STATEMENT - instruction sequence (multiline square bracket notation)
  # Example: STATEMENT([PUSH(42), LOAD_LOCAL(x), ADD, PRINT])
  # Formats as:
  #   [
  #       PUSH(42)
  #       LOAD_LOCAL(x)
  #       ADD
  #       PRINT
  #   ]
  def format_statement_node(stmt)
    result = indent + "[\n"
    increase_indent do
      stmt.instructions.each do |instr|
        result += indent + format_instruction(instr) + "\n"
      end
    end
    result += indent + "]\n"
    result
  end

  # BLOCK - labeled basic block
  # Example: BLOCK('L0', [PUSH(42), STORE_GLOBAL(x)])
  # Formats as:
  #   L0:
  #       PUSH(42)
  #       STORE_GLOBAL(x)
  def format_block(stmt)
    result = indent + "#{stmt.label}:\n"
    increase_indent do
      stmt.instructions.each do |instr|
        result += indent + format_instruction(instr) + "\n"
      end
    end
    result += "\n"
    result
  end

  # ========================================================================
  # Expression formatters
  # ========================================================================

  def format_integerliteral(expr)
    expr.value.to_s
  end

  def format_name(expr)
    expr.value
  end

  def format_globalname(expr)
    "global[#{expr.value}]"
  end

  def format_localname(expr)
    "local[#{expr.value}]"
  end

  def format_binop(expr)
    left = format_expression(expr.left)
    right = format_expression(expr.right)

    # Add parentheses for clarity in nested expressions
    # But only when the left or right operands are also binary operations
    left = "(#{left})" if expr.left.is_a?(BinOp) && needs_parens?(expr.left, expr, :left)
    right = "(#{right})" if expr.right.is_a?(BinOp) && needs_parens?(expr.right, expr, :right)

    "#{left} #{expr.op} #{right}"
  end

  def format_unaryop(expr)
    operand = format_expression(expr.operand)
    "#{expr.op}#{operand}"
  end

  def format_call(expr)
    args = expr.args.map { |arg| format_expression(arg) }.join(', ')
    "#{expr.func}(#{args})"
  end

  # EXPR - instruction sequence (compact square bracket notation)
  # Example: EXPR([PUSH(42), LOAD_LOCAL(x), ADD]) => "[PUSH(42), LOAD_LOCAL(x), ADD]"
  def format_expr(expr)
    instructions_str = expr.instructions.map { |i| format_instruction(i) }.join(', ')
    "[#{instructions_str}]"
  end

  # ========================================================================
  # Instruction formatters
  # ========================================================================

  # Simple instructions that just return their uppercase class name
  # Replace Method with Data: Eliminates 14 trivial one-line methods
  SIMPLE_INSTRUCTIONS = %w[
    ADD SUB MUL DIV
    LT GT LE GE EQ NE
    AND OR
    NEG NOT
    PRINT RETURN
  ].freeze

  # uses dynamic dispatch with _instr suffix to avoid conflicts with expression formatters
  def format_instruction(instr)
    class_name = instr.class.name

    # Check if this is a simple instruction (no attributes)
    return class_name if SIMPLE_INSTRUCTIONS.include?(class_name)

    # Otherwise use dynamic dispatch for complex instructions
    dynamic_format(instr, suffix: '_instr', error_prefix: 'instruction ')
  end

  # Value instructions
  def format_push_instr(instr)
    "PUSH(#{instr.value})"
  end

  # Memory instructions
  def format_load_global_instr(instr)
    "LOAD_GLOBAL(#{instr.name})"
  end

  def format_load_local_instr(instr)
    "LOAD_LOCAL(#{instr.name})"
  end

  # Function call instruction
  def format_call_instr(instr)
    "CALL(#{instr.name}, #{instr.nargs})"
  end

  # Statement instructions
  def format_store_global_instr(instr)
    "STORE_GLOBAL(#{instr.name})"
  end

  def format_store_local_instr(instr)
    "STORE_LOCAL(#{instr.name})"
  end

  def format_local_instr(instr)
    "LOCAL(#{instr.name})"
  end

  # Control flow instructions
  def format_goto_instr(instr)
    "GOTO(#{instr.label})"
  end

  def format_cbranch_instr(instr)
    "CBRANCH(#{instr.true_label}, #{instr.false_label})"
  end

  # LLVM instructions (Walrus 12)
  def format_llvm_instr(instr)
    "LLVM(#{instr.op})"
  end

  # ========================================================================
  # Helper methods
  # ========================================================================

  # Get current indentation string
  def indent
    ' ' * (@indent_level * @indent_size)
  end

  # Increase indentation for a block
  def increase_indent
    @indent_level += 1
    yield
  ensure
    @indent_level -= 1
  end
end

# ============================================================================
# Convenience functions for formatting
# ============================================================================

def format_program(program)
  Formatter.new.format_program(program)
end

def format_statement(stmt)
  Formatter.new.format_statement(stmt)
end

def format_expression(expr)
  Formatter.new.format_expression(expr)
end
