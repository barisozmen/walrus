require 'tty-tree'
require 'pastel'
require_relative '../model'

# Ensure Walrus.pastel is available
module Walrus
  def self.pastel
    @pastel ||= Pastel.new
  end
end

module Walrus
  class AstPrinter
    def initialize(pastel = Walrus.pastel)
      @pastel = pastel
    end

    def print(node)
      tree_hash = to_tree_hash(node)
      TTY::Tree.new(tree_hash).render
    end

    private

    def to_tree_hash(node, inline: false)
      unless node.is_a?(Node)
        return node.to_s
      end

      if inline || is_simple?(node)
        return compact_repr(node)
      end

      label = build_label(node)
      children = build_children(node)

      return label if children.empty?
      { label => children }
    end

    def is_simple?(node)
      node.is_a?(IntegerLiteral) ||
        node.is_a?(FloatLiteral) ||
        node.is_a?(Name) ||
        node.is_a?(LocalName) ||
        node.is_a?(GlobalName)
    end

    def compact_repr(node)
      case node
      when IntegerLiteral then node.value.to_s
      when FloatLiteral then node.value.to_s
      when Name then "Name(#{node.value})"
      when LocalName then "LocalName(#{node.value})"
      when GlobalName then "GlobalName(#{node.value})"
      when BinOp then "#{compact_repr(node.left)} #{node.op} #{compact_repr(node.right)}#{type_annotation(node)}"
      else build_label(node)
      end
    end

    def build_label(node)
      color = color_for_node(node)
      text = case node
      when IntegerLiteral then "#{node.value}"
      when Name then "Name(#{node.value})#{type_annotation(node)}"
      when LocalName then "LocalName(#{node.value})#{type_annotation(node)}"
      when GlobalName then "GlobalName(#{node.value})#{type_annotation(node)}"
      when VarDeclarationWithInit then "var #{node.name} = #{compact_repr(node.value)}#{type_annotation(node)}"
      when VarDeclarationWithoutInit then "var #{node.name}#{type_annotation(node)}"
      when LocalVarDeclarationWithoutInit then "local #{node.name}#{type_annotation(node)}"
      when GlobalVarDeclarationWithoutInit then "global #{node.name}#{type_annotation(node)}"
      when LocalVarDeclarationWithInit then "local #{node.name} = #{compact_repr(node.value)}#{type_annotation(node)}"
      when GlobalVarDeclarationWithInit then "global #{node.name} = #{compact_repr(node.value)}#{type_annotation(node)}"
      when Assignment
        val = compact_repr(node.value)
        "#{compact_node(node.name_ref)} = #{val}"
      when BinOp then compact_repr(node)
      when UnaryOp then "#{node.op}#{compact_repr(node.operand)}#{type_annotation(node)}"
      when If then "If"
      when While then "While"
      when Function
        params_list = node.params.is_a?(Array) ? node.params : [node.params]
        param_names = params_list.map do |p|
          if p.is_a?(Parameter) && p.type
            "#{p.name}: #{p.type}"
          elsif p.is_a?(Parameter)
            p.name
          else
            p
          end
        end.join(', ')
        "Function(#{node.name}, params=[#{param_names}])#{type_annotation(node)}"
      when Return then is_simple?(node.value) ? "Return(#{compact_repr(node.value)})" : "Return"
      when Print then is_simple?(node.value) ? "Print(#{compact_repr(node.value)})" : "Print"
      when Call
        if node.args.all? { |a| is_simple?(a) }
          args = node.args.map { |a| compact_repr(a) }.join(', ')
          "Call(#{node.func}, [#{args}])#{type_annotation(node)}"
        else
          "Call(#{node.func})#{type_annotation(node)}"
        end
      when Program then "Program"
      when BLOCK then "BLOCK(#{node.label})"
      else node.class.name
      end

      @pastel.decorate(text, color)
    end

    def type_annotation(node)
      return '' unless node.respond_to?(:type) && node.type
      " #{@pastel.dim("(#{node.type})")}"
    end

    def compact_node(node)
      case node
      when IntegerLiteral then node.value.to_s
      when Name, LocalName, GlobalName then node.value
      when BinOp then "#{compact_node(node.left)} #{node.op} #{compact_node(node.right)}"
      else node.class.name
      end
    end

    def build_children(node)
      children = {}

      case node
      when Program
        node.statements.each_with_index { |stmt, i| children["[#{i}]"] = to_tree_hash(stmt) }
      when Function
        body_list = node.body.is_a?(Array) ? node.body : [node.body]
        body_list.each_with_index { |stmt, i| children["body[#{i}]"] = to_tree_hash(stmt) }
      when If
        add_inline_child(children, "condition", compact_repr(node.condition))
        add_block_children(children, "then", node.then_block)
        add_block_children(children, "else", node.else_block) unless node.else_block.empty?
      when While
        add_inline_child(children, "condition", compact_repr(node.condition))
        add_block_children(children, "body", node.body)
      when BinOp
        add_inline_child(children, "left", to_tree_hash(node.left, inline: true))
        add_inline_child(children, "right", to_tree_hash(node.right, inline: true))
      when UnaryOp
        add_inline_child(children, "operand", to_tree_hash(node.operand, inline: true))
      when VarDeclarationWithInit, Assignment
        # Value shown in label
      when Return, Print
        children["value"] = to_tree_hash(node.value) unless is_simple?(node.value)
      when Call
        unless node.args.all? { |a| is_simple?(a) }
          node.args.each_with_index { |arg, i| add_inline_child(children, "arg[#{i}]", to_tree_hash(arg, inline: true)) }
        end
      when BLOCK
        node.instructions.each_with_index { |instr, i| children["[#{i}]"] = to_tree_hash(instr) }
      end

      children
    end

    def add_inline_child(children, label, value)
      children["#{label}: #{value}"] = {}
    end

    def add_block_children(children, label, block)
      block.each_with_index { |stmt, i| children["#{label}[#{i}]"] = to_tree_hash(stmt) }
    end

    def color_for_node(node)
      case node
      when Statement then :green
      when Expression then :cyan
      when Literal then :yellow
      when INSTRUCTION then :magenta
      else :white
      end
    end
  end
end
