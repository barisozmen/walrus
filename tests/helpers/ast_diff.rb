require 'minitest/assertions'
require 'pastel'
require_relative '../../model'
require_relative '../../compile/ast_printer'
require_relative 'tree_differ'

module Minitest::Assertions
  alias_method :original_diff, :diff

  def diff(exp, act)
    if exp.is_a?(Node) && act.is_a?(Node)
      pastel = Walrus.pastel
      printer = Walrus::AstPrinter.new(Pastel.new(enabled: false))

      expected_tree = printer.print(exp)
      actual_tree = printer.print(act)

      expected_lines = expected_tree.lines.map(&:chomp)
      actual_lines = actual_tree.lines.map(&:chomp)

      differ = Walrus::TreeDiffer.new(pastel)
      diff_output = []
      diff_output << ""
      diff_output << pastel.cyan.bold("━" * 80)
      diff_output << pastel.cyan.bold("DIFF (- expected, + actual):")
      diff_output << pastel.cyan.bold("━" * 80)
      diff_output << differ.diff(expected_lines, actual_lines)
      diff_output << ""

      return diff_output.join("\n")
    end

    original_diff(exp, act)
  end
end
