require 'pastel'

module Walrus
  class TreeDiffer
    def initialize(pastel = Walrus.pastel)
      @pastel = pastel
    end

    def diff(expected_lines, actual_lines)
      changes = lcs_diff(expected_lines, actual_lines)
      format_diff(changes)
    end

    private

    def lcs_diff(a, b)
      m, n = a.length, b.length
      dp = Array.new(m + 1) { Array.new(n + 1, 0) }

      (1..m).each do |i|
        (1..n).each do |j|
          dp[i][j] = if a[i - 1] == b[j - 1]
            dp[i - 1][j - 1] + 1
          else
            [dp[i - 1][j], dp[i][j - 1]].max
          end
        end
      end

      backtrack_diff(a, b, dp, m, n)
    end

    def backtrack_diff(a, b, dp, i, j)
      return [] if i == 0 && j == 0

      if i > 0 && j > 0 && a[i - 1] == b[j - 1]
        backtrack_diff(a, b, dp, i - 1, j - 1) + [[:same, a[i - 1]]]
      elsif j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])
        backtrack_diff(a, b, dp, i, j - 1) + [[:add, b[j - 1]]]
      elsif i > 0
        backtrack_diff(a, b, dp, i - 1, j) + [[:remove, a[i - 1]]]
      else
        []
      end
    end

    def format_diff(changes)
      output = []
      context = 3

      changes.each_with_index do |change, idx|
        type, line = change

        case type
        when :same
          if near_change?(changes, idx, context)
            output << @pastel.dim("  #{line}")
          elsif idx > 0 && changes[idx - 1][0] != :same
            output << @pastel.dim("  ...")
          end
        when :remove
          output << @pastel.red.bold("- #{line}")
        when :add
          output << @pastel.green.bold("+ #{line}")
        end
      end

      output.reject { |line| line == @pastel.dim("  ...") && output.count(line) > 1 }.join("\n")
    end

    def near_change?(changes, idx, context)
      range = [[idx - context, 0].max, [idx + context, changes.length - 1].min]
      (range[0]..range[1]).any? { |i| changes[i][0] != :same }
    end
  end
end
