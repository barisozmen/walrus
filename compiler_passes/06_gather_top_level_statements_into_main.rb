# Unscript pass - Walrus 4: The Unscripted
# Takes all top-level statements and moves them into a main() function,
# except for global variable declarations and function definitions.
#
# This transforms a script-like program into a more structured program
# where all executable code is contained within functions.
#
# Example transformation:
# Before:
#   global v;
#   global[v] = 9;
#   func square(x) { ... }
#   global result;
#   global[result] = square(global[v]);
#   print global[result];
#
# After:
#   global v;
#   func square(x) { ... }
#   global result;
#   func main() {
#       global[v] = 9;
#       global[result] = square(global[v]);
#       print global[result];
#   }

require_relative 'base'

module Walrus
  class GatherTopLevelStatementsIntoMain < CompilerPass
    def run(program)
      raise ArgumentError, "Expected Program, got #{program.class}" unless program.is_a?(Program)

      # Separate statements into two categories:
      # 1. Functions (stay at top level)
      # 2. Everything else (moves into main)
      main_body = []
      others = []

      program.statements.each do |stmt|
        if stmt.is_a?(Function) || stmt.is_a?(GlobalVarDeclarationWithoutInit) || stmt.is_a?(GlobalVarDeclarationWithInit)
          others << stmt
        else
          main_body << stmt
        end
      end

      # If there are no statements for main, return program unchanged
      return program if main_body.empty?

      # Create main() function with the transformed statements
      main_func = Function.new('main', [], main_body, type: 'int')

      # Build new program with functions first, then main() at the end
      Program.new(others + [main_func])
    end
  end
end
