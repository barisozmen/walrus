# Lower For Loops to While Loops
#
# Transforms for-loops into semantically equivalent while-loops:
#   for (init; condition; update) { body }
#   =>
#   init;
#   while condition { body; update; }
#
# This syntactic transformation happens early in the pipeline, before type
# inference and scope resolution. Subsequent passes only see while-loops.
#
# Example:
#   for (var i = 0; i < 10; i = i + 1) {
#     print i;
#   }
#   =>
#   var i = 0;
#   while i < 10 {
#     print i;
#     i = i + 1;
#   }

require_relative 'base'

module Walrus
  class LowerForLoopsToWhileLoops < AstTransformerBasedCompilerPass
    def transform_forloop(node, context)
      # Transform body recursively (handles nested for-loops)
      transformed_body = transform(node.body, context)

      # Build while body: transformed body + update statement
      while_body = transformed_body.dup
      while_body << transform(node.update, context) if node.update

      # Build result: init (if present) + while loop
      statements = []
      statements << transform(node.init, context) if node.init
      statements << While.new(transform(node.condition, context), while_body)

      MultipleStatements.new(statements)
    end
  end
end
