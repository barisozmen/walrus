# model.rb
#
# Data model for the Walrus programming language.
# This file defines the Abstract Syntax Tree (AST) node classes
# using advanced Ruby metaprogramming techniques.
require 'singleton'
require_relative 'lib/type_mapper'
require_relative 'compile/context'

# Source location for error reporting
SourceLocation = Struct.new(:lineno, :column, :source_line, :filename) do
  def to_s
    "line #{lineno}, column #{column}"
  end
end

# Base class for all AST nodes with metaprogramming utilities
class Node
  attr_accessor :context, :parent, :loc

  # Default initialize for nodes without children
  # if 'children' called for a node, it will override this initialize method 
  def initialize(**kwargs)
    @type = kwargs[:type] if kwargs.key?(:type) && respond_to?(:type=)
  end

  # Class-level metaprogramming: automatically generate visitor acceptance
  def self.inherited(subclass)
    subclass.class_eval do
      # Allow visitors to process nodes
      def accept(visitor)
        method_name = "visit_#{self.class.name.downcase}"
        if visitor.respond_to?(method_name, true)
          visitor.send(method_name, self)
        else
          raise "Visitor does not implement #{method_name}"
        end
      end
    end
  end

  def inspect
    attrs = instance_variables.map do |var|
      value = instance_variable_get(var)
      "#{var}=#{value.inspect}"
    end
    "#<#{self.class.name} #{attrs.join(', ')}>"
  end

  def pretty_inspect
    require_relative 'pretty/ast_printer'
    AstPrinter.new.print(self)
  end

  # Metaprogramming: Automatically create attr_reader and constructor
  # Usage: children :name, :value
  def self.children(*names)
    attr_reader(*names)

    define_method(:initialize) do |*args, **kwargs|
      instance_variable_set("@children_names", names)

      names.each_with_index do |name, index|
        instance_variable_set("@#{name}", args[index])
      end

      # Support type: kwarg if this class has @type (set by typed)
      @type = kwargs[:type] if kwargs.key?(:type) && respond_to?(:type=)
    end

    define_method(:attr_names) do
      @children_names
    end

    # Add equality comparison
    define_method(:==) do |other|
      return false unless other.is_a?(self.class)
      names.all? do |name|
        instance_variable_get("@#{name}") == other.instance_variable_get("@#{name}")
      end
    end

    # Add hash for use in sets/hashes
    define_method(:hash) do
      [self.class, *names.map { |name| instance_variable_get("@#{name}") }].hash
    end

    alias_method :eql?, :==
  end

  # Add type support to a class (used by Expression, Parameter, etc.)
  # children method will handle type: kwarg automatically
  def self.typed
    attr_accessor :type
  end
end

# ============================================================================
# Abstract base classes for organization
# ============================================================================

class Statement < Node
  # Base class for all statements (actions)
end

class Expression < Node
  # Base class for all expressions (values)
  typed  # Type attribute for Walrus type system (Phase 1)
end


class MultipleStatements < Statement
  children :statements

  # Allow array-like access
  def [](index)
    @statements[index]
  end

  def length
    @statements.length
  end

  def each(&block)
    @statements.each(&block)
  end
end

# ============================================================================
# Statement nodes
# ============================================================================

# Function parameter with type
# Example: x int (in function signature)
class Parameter < Node
  children :name
  typed
end

# Example: var x = 10;
class VarDeclarationWithInit < Statement
  children :name, :value
  typed
end

# Example: var x int;
class VarDeclarationWithoutInit < Statement
  children :name
  typed
end

# Scoped variable declarations (after resolve pass)
class GlobalVarDeclarationWithoutInit < VarDeclarationWithoutInit
end

class LocalVarDeclarationWithoutInit < VarDeclarationWithoutInit
end

class GlobalVarDeclarationWithInit < VarDeclarationWithInit
end

class LocalVarDeclarationWithInit < VarDeclarationWithInit
end

# Assignment to existing variable
# Example: x = x + 1;
# Note: name is a Name/GlobalName/LocalName node, not a string
class Assignment < Statement
  children :name_ref, :value
end

# Example: print x;
class Print < Statement
  children :value
end

# Example: var x = gets;
class Gets < Expression
  typed
end

# Example: if x < y { ... } else { ... }
class If < Statement
  children :condition, :then_block, :else_block
end

# Example: if x < 0 { a } elsif x == 0 { b } else { c }
class ElsIf < Statement
  children :condition, :then_block, :elsif_branches, :else_block
end

# Single elsif branch
class ElsIfBranch < Node
  children :condition, :then_block
end

# Example: case x { when 1 { a } when 2 { b } else { c } }
class Case < Statement
  children :test_expr, :when_branches, :else_block
end

# Single when branch
class WhenBranch < Node
  children :match_expr, :then_block
end

# Example: while x < 10 { ... }
class While < Statement
  children :condition, :body
end

# Example: for (var i = 0; i < 10; i = i + 1) { ... }
class ForLoop < Statement
  children :init, :condition, :update, :body
end

# Example: func add1(x int) int { ... }
class Function < Statement
  children :name, :params, :body
  typed  # String: 'int', 'float', 'bool', 'char'. Type of a function is its return type 
end

# Example: return x;
class Return < Statement
  children :value
end

# Example: break;
class Break < Statement
end

# Example: continue;
class Continue < Statement
end

# Example: f(x); or 2 + 3;
# Expression evaluated as a statement - result discarded
class ExprStatement < Statement
  children :value
end

# ============================================================================
# Expression nodes
# ============================================================================
class Literal < Expression
end

# Example: 42
class IntegerLiteral < Literal
  children :value
end

# Example: 3.14
class FloatLiteral < Literal
  children :value
end

# Example: 'a', '\n'
class CharacterLiteral < Literal
  children :value
end

# Example: "hello"
class StringLiteral < Literal
  children :value
end

# Variable reference
# Example: x
class Name < Expression
  children :value
end

# Scoped variable references (after resolve pass)
class GlobalName < Name
end

class LocalName < Name
end

# Example: 2 + 3, x < y
class BinOp < Expression
  children :op, :left, :right

  # Operator categories for formatting
  ARITHMETIC_OPS = %w[+ - * /].freeze
  COMPARISON_OPS = %w[< > <= >= == !=].freeze
  LOGICAL_OPS = %w[&& ||].freeze

  def arithmetic?
    ARITHMETIC_OPS.include?(@op)
  end

  def comparison?
    COMPARISON_OPS.include?(@op)
  end

  def logical?
    LOGICAL_OPS.include?(@op)
  end
end

# Example: -x, !flag
class UnaryOp < Expression
  children :op, :operand
end

# Example: add1(x)
class Call < Expression
  children :func, :args
end

# ============================================================================
# Machine Instructions (Walrus 8 - Expression Code)
# ============================================================================

# Base class for all machine instructions
# Instructions represent stack-based machine operations
class INSTRUCTION < Node
  # Instructions without attributes should be equal if they're the same class
  def ==(other)
    return false unless other.is_a?(self.class)
    return true if instance_variables.empty?

    # For instructions with attributes, compare them
    instance_variables.all? do |var|
      instance_variable_get(var) == other.instance_variable_get(var)
    end
  end

  def hash
    [self.class, *instance_variables.map { |var| instance_variable_get(var) }].hash
  end

  class << self
    attr_accessor :llvm_code
  end

  alias_method :eql?, :==
end


# Register generator for SSA (Static Single Assignment)
# LLVM requires each register to be assigned only once
class LLVMRegisterNameGenerator
  @count = 0

  class << self
    def next
      @count += 1
      "%.#{@count}"
    end
    def reset
      @count = 0
    end
  end
end

# LLVM instruction (Walrus 12 - LLVM Code Generation)
# Holds an LLVM-specific instruction string
# Example: LLVM("%.0 = add i32 10, 20")
class LLVM < INSTRUCTION
  children :op
end


# Value instructions
class PUSH < INSTRUCTION
  typed
  children :value

  def get_llvm_code(stack, type_map)
    value_str = value.to_s

    if type == 'str'
      # String literals: generate getelementptr to global constant
      global_strings = Walrus.context[:global_strings] || {}
      string_value = global_strings[value_str] || ""
      length = string_value.length + 1

      reg = LLVMRegisterNameGenerator.next
      stack.push(reg)
      type_map[reg] = 'i8*'

      LLVM.new("#{reg} = getelementptr [#{length} x i8], [#{length} x i8]* #{value_str}, i32 0, i32 0")
    else
      # Regular literals: just push to stack, no code generation
      stack.push(value_str)
      type_map[value_str] = if type
        TypeMapper.to_llvm(type)
      else
        value_str.include?('.') ? 'double' : 'i32'
      end
      nil  # No instruction to emit
    end
  end
end

class BINARY_INSTRUCTION < INSTRUCTION;
  class << self
    attr_accessor :llvm_code
  end

  def get_llvm_code stack, type_map
    right_reg = stack.pop
    left_reg = stack.pop

    # Determine type from type_map
    llvm_type = type_map[left_reg] || type_map[right_reg] || 'i32'

    target_reg = LLVMRegisterNameGenerator.next
    type_map[target_reg] = llvm_type
    stack.push target_reg
    LLVM.new "#{target_reg} = #{self.class.llvm_code} #{llvm_type} #{left_reg}, #{right_reg}"
  end
end

# Arithmetic instructions (no attributes - just class identity)
class ARITHMETIC_INSTRUCTION < BINARY_INSTRUCTION
  def get_llvm_code stack, type_map
    right_reg = stack.pop
    left_reg = stack.pop

    llvm_type = type_map[left_reg] || type_map[right_reg] || 'i32'
    is_float = llvm_type == 'double'

    # Special handling for DIV: sdiv for integers, fdiv for floats
    if self.is_a?(DIV)
      llvm_op = is_float ? 'fdiv' : 'sdiv'
    else
      llvm_op = is_float ? "f#{self.class.llvm_code}" : self.class.llvm_code
    end

    target_reg = LLVMRegisterNameGenerator.next
    type_map[target_reg] = llvm_type
    stack.push target_reg
    LLVM.new "#{target_reg} = #{llvm_op} #{llvm_type} #{left_reg}, #{right_reg}"
  end
end

class ADD < ARITHMETIC_INSTRUCTION
  self.llvm_code = 'add'
end
class SUB < ARITHMETIC_INSTRUCTION
  self.llvm_code = 'sub'
end
class MUL < ARITHMETIC_INSTRUCTION
  self.llvm_code = 'mul'
end
class DIV < ARITHMETIC_INSTRUCTION
end

# Comparison instructions (no attributes - just class identity)
class COMPARISON_INSTRUCTION < BINARY_INSTRUCTION
  def get_llvm_code stack, type_map
    right_reg = stack.pop
    left_reg = stack.pop

    llvm_type = type_map[left_reg] || type_map[right_reg] || 'i32'
    is_float = llvm_type == 'double'
    llvm_op = is_float ? self.class.llvm_code.sub('icmp s', 'fcmp o') : self.class.llvm_code

    target_reg = LLVMRegisterNameGenerator.next
    type_map[target_reg] = 'i1'  # Comparisons always return bool
    stack.push target_reg
    LLVM.new "#{target_reg} = #{llvm_op} #{llvm_type} #{left_reg}, #{right_reg}"
  end
end

class LT < COMPARISON_INSTRUCTION
  self.llvm_code = 'icmp slt'
end
class GT < COMPARISON_INSTRUCTION
  self.llvm_code = 'icmp sgt'
end
class LE < COMPARISON_INSTRUCTION
  self.llvm_code = 'icmp sle'
end
class GE < COMPARISON_INSTRUCTION
  self.llvm_code = 'icmp sge'
end
class EQ < COMPARISON_INSTRUCTION
  self.llvm_code = 'icmp eq'

  def get_llvm_code stack, type_map
    right_reg = stack.pop
    left_reg = stack.pop

    llvm_type = type_map[left_reg] || type_map[right_reg] || 'i32'
    llvm_op = llvm_type == 'double' ? 'fcmp oeq' : 'icmp eq'

    target_reg = LLVMRegisterNameGenerator.next
    type_map[target_reg] = 'i1'
    stack.push target_reg
    LLVM.new "#{target_reg} = #{llvm_op} #{llvm_type} #{left_reg}, #{right_reg}"
  end
end

class NE < COMPARISON_INSTRUCTION
  self.llvm_code = 'icmp ne'

  def get_llvm_code stack, type_map
    right_reg = stack.pop
    left_reg = stack.pop

    llvm_type = type_map[left_reg] || type_map[right_reg] || 'i32'
    llvm_op = llvm_type == 'double' ? 'fcmp one' : 'icmp ne'

    target_reg = LLVMRegisterNameGenerator.next
    type_map[target_reg] = 'i1'
    stack.push target_reg
    LLVM.new "#{target_reg} = #{llvm_op} #{llvm_type} #{left_reg}, #{right_reg}"
  end
end

# Logical instructions (no attributes - just class identity)
class LOGICAL_INSTRUCTION < INSTRUCTION; end
class AND < LOGICAL_INSTRUCTION; end
class OR < LOGICAL_INSTRUCTION; end

# Unary instructions (no attributes - just class identity)
class UNARY_INSTRUCTION < INSTRUCTION
  class << self
    attr_accessor :llvm_code
  end

  def get_llvm_code stack, type_map
    operand_reg = stack.pop
    target_reg = LLVMRegisterNameGenerator.next
    llvm_type = type_map[operand_reg] || 'i32'
    type_map[target_reg] = llvm_type
    stack.push target_reg
    LLVM.new "#{target_reg} = #{self.class.llvm_code} #{llvm_type} 0, #{operand_reg}"
  end
end
class NEG < UNARY_INSTRUCTION
  def get_llvm_code stack, type_map
    operand_reg = stack.pop
    target_reg = LLVMRegisterNameGenerator.next

    llvm_type = type_map[operand_reg] || 'i32'
    is_float = llvm_type == 'double'
    type_map[target_reg] = llvm_type
    stack.push target_reg

    if is_float
      LLVM.new "#{target_reg} = fneg double #{operand_reg}"
    else
      LLVM.new "#{target_reg} = sub i32 0, #{operand_reg}"
    end
  end
end
class NOT < UNARY_INSTRUCTION
  self.llvm_code = 'icmp eq'
end

class MEMORY_INSTRUCTION < INSTRUCTION
  typed

  class << self
    attr_accessor :llvm_memory_sig
  end
end

# Memory instructions
class LOAD_INSTRUCTION < MEMORY_INSTRUCTION
  def get_llvm_code stack, type_map
    target_reg = LLVMRegisterNameGenerator.next
    llvm_type = TypeMapper.to_llvm(self.type)
    type_map[target_reg] = llvm_type
    stack.push target_reg
    LLVM.new "#{target_reg} = load #{llvm_type}, #{llvm_type}* #{self.class.llvm_memory_sig}#{self.name}"
  end
end

class LOAD_GLOBAL < LOAD_INSTRUCTION
  children :name
  self.llvm_memory_sig = '@'
end

class LOAD_LOCAL < LOAD_INSTRUCTION
  children :name
  self.llvm_memory_sig = '%'
end

class STORE_INSTRUCTION < MEMORY_INSTRUCTION
  def get_llvm_code stack, type_map
    target_reg = stack.pop
    llvm_type = type_map[target_reg] || 'i32'
    LLVM.new "store #{llvm_type} #{target_reg}, #{llvm_type}* #{self.class.llvm_memory_sig}#{self.name}"
  end
end

class STORE_GLOBAL < STORE_INSTRUCTION
  children :name
  self.llvm_memory_sig = '@'
end

class STORE_LOCAL < STORE_INSTRUCTION
  children :name
  self.llvm_memory_sig = '%'
end

# Function call instruction
class CALL < INSTRUCTION
  children :name, :nargs
  typed
  attr_accessor :param_types

  def get_llvm_code stack, type_map
    args = stack.pop(nargs).reverse

    # Get actual LLVM types from the registers on the stack (not from signature)
    llvm_param_types = args.map { |reg| type_map[reg] || 'i32' }

    llvm_return_type = TypeMapper.to_llvm(self.type)

    # Build call with correct types
    args_str = args.zip(llvm_param_types).map { |reg, type| "#{type} #{reg}" }.join(", ")
    sig = "(#{llvm_param_types.join(', ')})"

    target_reg = LLVMRegisterNameGenerator.next
    type_map[target_reg] = llvm_return_type
    stack.push target_reg

    LLVM.new "#{target_reg} = call #{llvm_return_type} #{sig} @#{name}(#{args_str})"
  end
end

class PRINT < INSTRUCTION
  def get_llvm_code stack, type_map
    value = stack.pop
    llvm_type = type_map[value] || 'i32'

    case llvm_type
    when 'double'
      LLVM.new "call i32 (double) @_print_float(double #{value})"
    when 'i8'
      LLVM.new "call i32 (i8) @_print_char(i8 #{value})"
    when 'i8*'
      LLVM.new "call i32 (i8*) @_print_str(i8* #{value})"
    else
      LLVM.new "call i32 (i32) @_print_int(i32 #{value})"
    end
  end
end

class GETS < INSTRUCTION
  def get_llvm_code stack, type_map
    target_reg = LLVMRegisterNameGenerator.next
    type_map[target_reg] = 'i32'
    stack.push target_reg
    LLVM.new "#{target_reg} = call i32 () @_gets_int()"
  end
end

class RETURN < INSTRUCTION
  def get_llvm_code stack, type_map
    raise "stack during RETURN shouldnt be empty" if stack.empty?
    value = stack.pop
    llvm_type = type_map[value] || 'i32'
    LLVM.new("ret #{llvm_type} #{value}")
  end
end

class LOCAL < INSTRUCTION
  typed
  children :name
  def get_llvm_code stack, type_map
    llvm_type = TypeMapper.to_llvm(self.type)
    LLVM.new("%#{name} = alloca #{llvm_type}")
  end
end

# Control flow instructions (Walrus 11)
class GOTO < INSTRUCTION
  children :label
  def get_llvm_code stack, type_map
    LLVM.new "br label %#{label}"
  end
end

class CBRANCH < INSTRUCTION
  children :true_label, :false_label
  def get_llvm_code stack, type_map
    condition = stack.pop
    LLVM.new "br i1 #{condition}, label %#{true_label}, label %#{false_label}"
  end
end








# STATEMENT - Statement as instruction sequence
# Replaces statements with flat list of stack-based instructions
# Example: Print(EXPR([PUSH(42), LOAD_LOCAL('x'), ADD()]))
#       => STATEMENT([PUSH(42), LOAD_LOCAL('x'), ADD(), PRINT()])
class STATEMENT < Statement
  children :instructions
end

# BLOCK - Basic block (labeled instruction sequence)
# Groups adjacent STATEMENT nodes into single labeled blocks
# Example: STATEMENT([PUSH(10), STORE_GLOBAL(x)]), STATEMENT([LOAD_GLOBAL(x), PRINT()])
#       => BLOCK('L0', [PUSH(10), STORE_GLOBAL(x), LOAD_GLOBAL(x), PRINT()])
class BLOCK < Statement
  children :label, :instructions
end

# EXPR - Expression as instruction sequence
# Replaces expressions with flat list of stack-based instructions
# Example: BinOp('+', int(42), LocalName('x'))
#       => EXPR([PUSH(42), LOAD_LOCAL('x'), ADD()])
class EXPR < Expression
  children :instructions

  # Helper to flatten nested EXPR nodes into a single instruction list
  # Accepts EXPR nodes, INSTRUCTION nodes, or arrays of instructions
  # Returns a new EXPR with all instructions flattened
  def self.flatten(*items)
    instructions = items.flat_map do |item|
      case item
      when EXPR then item.instructions
      when INSTRUCTION then [item]
      when Array then item
      else
        raise ArgumentError, "Cannot flatten #{item.class}, expected EXPR, INSTRUCTION, or Array"
      end
    end
    new(instructions)
  end
end

# ============================================================================
# Top-level program container
# ============================================================================

class Program < Node
  children :statements

  # Helper to create a program from a list
  def self.from_list(statements)
    new(statements)
  end

  # Access statements like an array
  def [](index)
    @statements[index]
  end

  def length
    @statements.length
  end

  def each(&block)
    @statements.each(&block)
  end
end
